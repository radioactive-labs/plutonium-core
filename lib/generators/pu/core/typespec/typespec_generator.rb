# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Core
    class TypespecGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Generate TypeSpec API specifications from Plutonium resources"

      class_option :output, type: :string, default: "typespec", desc: "Output directory for TypeSpec files"
      class_option :portal, type: :string, desc: "Generate specs for a specific portal only"

      def start
        load_application
        check_pending_migrations!
        detect_portals
        generate_typespec_files
      end

      private

      attr_reader :portals

      def load_application
        say_status :loading, "Rails application", :blue
        Rails.application.eager_load!
        Rails.application.reload_routes!
      end

      def check_pending_migrations!
        context = ActiveRecord::MigrationContext.new(ActiveRecord::Migrator.migrations_paths)
        pending = context.migrations.select { |m| !context.get_all_versions.include?(m.version) }

        return if pending.empty?

        say_status :error, "Pending migrations detected!", :red
        pending.each do |migration|
          say_status :pending, "#{migration.version} - #{migration.name}", :yellow
        end
        say ""
        say "Run `bin/rails db:migrate` before generating TypeSpec specifications.", :red
        raise Thor::Error, "Cannot generate TypeSpec with pending migrations"
      end

      def detect_portals
        say_status :detecting, "portals", :blue
        @portals = []

        Rails::Engine.subclasses.each do |engine|
          next unless engine.included_modules.any? { |m| m.name&.include?("Plutonium::Portal") }

          portal_name = engine.name.sub(/::Engine$/, "")
          route_path = find_engine_route_path(engine)

          next if options[:portal] && portal_name.underscore != options[:portal].underscore

          @portals << build_portal_data(engine, portal_name, route_path)
        end

        if @portals.empty?
          say_status :warning, "No portals found#{options[:portal] ? " matching '#{options[:portal]}'" : ""}", :yellow
        else
          @portals.each do |portal|
            say_status :found, "#{portal[:name]} (#{portal[:resources].size} resources)", :green
          end
        end
      end

      def find_engine_route_path(engine)
        Rails.application.routes.routes.find do |route|
          route.app.app == engine
        end&.path&.spec&.to_s&.gsub(/\(\.:format\)$/, "")
      end

      def build_portal_data(engine, portal_name, route_path)
        resources = []

        engine.resource_register.resources.each do |resource|
          route_config = engine.routes.resource_route_config_lookup[resource.model_name.plural]
          next unless route_config

          resource_data = build_resource_data(resource, route_config, portal_name, route_path)
          resources << resource_data if resource_data
        end

        {
          name: portal_name,
          engine: engine,
          route_path: route_path || "/#{portal_name.underscore}",
          file_name: portal_name.underscore.tr("/", "_"),
          resources: resources
        }
      end

      def build_resource_data(resource, route_config, portal_name, portal_route_path)
        return nil unless resource.table_exists?

        # Try portal-specific definition first, then fall back to base definition
        definition_class = safe_constantize("#{portal_name}::#{resource.name.demodulize}Definition") ||
          safe_constantize("#{resource.name}Definition")

        resource_path = route_config[:route_options][:path]
        full_route = [portal_route_path, resource_path].compact.join("/").gsub(%r{//+}, "/")

        {
          name: resource.name,
          typespec_name: resource.name.demodulize,
          file_name: resource.name.underscore.tr("/", "_"),
          table_name: resource.table_name,
          route_path: full_route,
          primary_key: resource.primary_key,
          primary_key_type: primary_key_type(resource),
          columns: build_columns_data(resource),
          associations: build_associations_data(resource),
          enums: build_enums_data(resource),
          definition: definition_class ? build_definition_data(definition_class, resource) : nil
        }
      rescue NameError => e
        say_status :skip, "#{resource.name}: #{e.message}", :yellow
        nil
      end

      def primary_key_type(resource)
        column_to_typespec_type(resource.columns.find { |c| c.name == resource.primary_key })
      end

      def column_to_typespec_type(column)
        return "int64" unless column
        TYPE_MAPPING[column.type] || "int64"
      end

      def build_columns_data(resource)
        resource.columns.map do |column|
          {
            name: column.name,
            type: column.type.to_s,
            null: column.null,
            default: column.default,
            typespec_type: TYPE_MAPPING[column.type] || "string"
          }
        end
      end

      def build_associations_data(resource)
        resource.reflect_on_all_associations.map do |assoc|
          fk_type = resolve_foreign_key_type(assoc, resource)

          {
            name: assoc.name.to_s,
            macro: assoc.macro.to_s,
            class_name: safe_association_attr(assoc, :klass)&.name,
            foreign_key: safe_association_attr(assoc, :foreign_key),
            foreign_key_type: fk_type,
            polymorphic: assoc.polymorphic?
          }
        end
      end

      def resolve_foreign_key_type(assoc, resource)
        return "int64" if assoc.polymorphic?

        # For belongs_to, look up the associated model's primary key type
        if assoc.macro == :belongs_to
          target_class = safe_association_attr(assoc, :klass)
          if target_class&.table_exists?
            pk_column = target_class.columns.find { |c| c.name == target_class.primary_key }
            return column_to_typespec_type(pk_column)
          end
        end

        # For has_many/has_one, use this resource's primary key type
        primary_key_type(resource)
      end

      def safe_association_attr(assoc, attr)
        assoc.public_send(attr)
      rescue NameError
        nil
      end

      def build_enums_data(resource)
        return {} unless resource.respond_to?(:defined_enums)
        resource.defined_enums.transform_values(&:keys)
      end

      def build_definition_data(definition_class, resource)
        inputs = extract_inputs(definition_class, resource)

        {
          class_name: definition_class.name,
          inputs: inputs
        }
      end

      def extract_inputs(definition_class, resource)
        return [] unless definition_class.respond_to?(:defined_inputs)

        defined_inputs = definition_class.defined_inputs
        return [] if defined_inputs.empty?

        defined_inputs.map do |name, config|
          input_config = config[:options] || {}
          column = resource.columns_hash[name.to_s]
          assoc = resource.reflect_on_association(name)

          {
            name: name.to_s,
            as: input_config[:as]&.to_s,
            required: !input_config[:optional],
            type: determine_input_type(name, input_config, column, assoc, resource),
            typespec_type: determine_typespec_input_type(name, input_config, column, assoc, resource),
            is_association: assoc.present?,
            is_polymorphic: assoc&.polymorphic?,
            association_macro: assoc&.macro&.to_s,
            nested: input_config[:nested].present?
          }
        end
      end

      def determine_input_type(name, config, column, assoc, resource)
        return config[:as].to_s if config[:as]
        return "association" if assoc
        return "enum" if resource.defined_enums.key?(name.to_s)
        return column.type.to_s if column
        "string"
      end

      def determine_typespec_input_type(name, config, column, assoc, resource)
        # Associations use SGIDs
        if assoc
          return "SignedGlobalId[]" if %i[has_many has_and_belongs_to_many].include?(assoc.macro)
          return "SignedGlobalId"
        end

        # Enums use the enum type
        return "#{resource.name.demodulize}#{name.to_s.camelize}" if resource.defined_enums.key?(name.to_s)

        # Use column type
        return TYPE_MAPPING[column.type] || "string" if column

        # Infer from as: option
        AS_TYPE_MAPPING[config[:as]&.to_sym] || "string"
      end

      def generate_typespec_files
        say_status :generating, "TypeSpec files", :blue

        empty_directory output_dir
        @single_portal = @portals.size == 1
        template "common.tsp.tt", "#{output_dir}/common.tsp"

        if @single_portal
          # Single portal - generate flat structure
          @current_portal = @portals.first
          generate_portal_files(@current_portal, output_dir)
        else
          # Multiple portals - generate per-portal directories
          @portals.each do |portal|
            portal_dir = "#{output_dir}/#{portal[:file_name]}"
            empty_directory portal_dir
            generate_portal_files(portal, portal_dir)
          end

          # Generate root main.tsp that imports all portals
          template "main_multi.tsp.tt", "#{output_dir}/main.tsp"
        end

        say_status :complete, "TypeSpec files generated in #{output_dir}/", :green
      end

      def generate_portal_files(portal, dir)
        @current_portal = portal
        template "main.tsp.tt", "#{dir}/main.tsp"

        empty_directory "#{dir}/models"

        portal[:resources].each do |resource|
          @current_resource = resource
          template "model.tsp.tt", "#{dir}/models/#{resource[:file_name]}.tsp"
        end
      end

      def output_dir
        options[:output]
      end

      def safe_constantize(name)
        name.constantize
      rescue NameError
        nil
      end

      TYPE_MAPPING = {
        string: "string",
        text: "string",
        integer: "int32",
        bigint: "int64",
        float: "float64",
        decimal: "decimal",
        boolean: "boolean",
        date: "plainDate",
        datetime: "utcDateTime",
        time: "plainTime",
        binary: "bytes",
        json: "Record<string, unknown>",
        jsonb: "Record<string, unknown>",
        uuid: "string",
        hstore: "Record<string, string>"
      }.freeze

      AS_TYPE_MAPPING = {
        text: "string",
        textarea: "string",
        markdown: "string",
        rich_text: "string",
        number: "int32",
        integer: "int32",
        decimal: "decimal",
        boolean: "boolean",
        checkbox: "boolean",
        date: "plainDate",
        datetime: "utcDateTime",
        time: "plainTime",
        file: "bytes",
        attachment: "bytes",
        email: "string",
        url: "url",
        phone: "string",
        password: "string",
        color: "string",
        json: "Record<string, unknown>",
        jsonb: "Record<string, unknown>",
        hstore: "Record<string, string>",
        key_value: "Record<string, string>"
      }.freeze
    end
  end
end
