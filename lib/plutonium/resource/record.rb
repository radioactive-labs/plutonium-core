module Plutonium
  module Resource
    module Record
      extend ActiveSupport::Concern

      included do
        scope :from_path_param, ->(param) { where(id: param) }

        scope :associated_with, ->(record) do
          named_scope = :"associated_with_#{record.model_name.singular}"
          return send(named_scope, record) if respond_to?(named_scope)

          # TODO: add support for polymorphic associations
          # TODO: add logging
          # TODO: memoize this

          own_association = klass.find_association_to_record(record)
          if own_association
            return klass.query_based_on_association(own_association, record)
          end

          record_association = klass.find_association_to_self(record)
          if record_association
            # TODO: add a warning here about a potentially poor performing query
            return where(id: record.public_send(record_association.name))
          end

          klass.raise_association_error(record, named_scope)
        end
      end

      class_methods do
        # Returns the resource field names
        # @return [Array<Symbol>]
        def resource_field_names
          return @resource_field_names if defined?(@resource_field_names) && !Rails.env.local?

          @resource_field_names = gather_resource_field_names
        end

        # Overrides belongs_to to add support for polymorphic associations
        # @param [Symbol] name The name of the association
        # @param [Proc] scope The scope for the association
        # @param [Hash] options The options for the association
        def belongs_to(name, scope = nil, **options)
          super(name, scope, **options)

          return unless options[:polymorphic]

          mod = Module.new
          mod.module_eval <<-RUBY, __FILE__, __LINE__ + 1
            extend ActiveSupport::Concern

            def #{name}_sgid
              #{name}&.to_signed_global_id
            end

            def #{name}_sgid=(sgid)
              self.#{name} = GlobalID::Locator.locate_signed(sgid)
            end

            define_singleton_method(:to_s) { "Plutonium::Polymorphic::BelongsTo(:#{name})" }
            define_singleton_method(:inspect) { "Plutonium::Polymorphic::BelongsTo(:#{name})" }
          RUBY
          include mod
        end

        # Returns the names of belongs_to associations
        # @return [Array<Symbol>]
        def belongs_to_association_field_names
          return @belongs_to_association_field_names if defined?(@belongs_to_association_field_names) && !Rails.env.local?

          @belongs_to_association_field_names = reflect_on_all_associations(:belongs_to).map(&:name)
        end

        # Returns the names of has_one associations
        # @return [Array<Symbol>]
        def has_one_association_field_names
          return @has_one_association_field_names if defined?(@has_one_association_field_names) && !Rails.env.local?

          @has_one_association_field_names = reflect_on_all_associations(:has_one)
            .map { |assoc| (!/_attachment$|_blob$/.match?(assoc.name)) ? assoc.name : nil }
            .compact
        end

        # Returns the names of has_many associations
        # @return [Array<Symbol>]
        def has_many_association_field_names
          return @has_many_association_field_names if defined?(@has_many_association_field_names) && !Rails.env.local?

          @has_many_association_field_names = reflect_on_all_associations(:has_many)
            .map { |assoc| (!/_attachments$|_blobs$/.match?(assoc.name)) ? assoc.name : nil }
            .compact
        end

        # Returns the names of has_one attached associations
        # @return [Array<Symbol>]
        def has_one_attached_field_names
          return @has_one_attached_field_names if defined?(@has_one_attached_field_names) && !Rails.env.local?

          @has_one_attached_field_names = if respond_to?(:reflect_on_all_attachments)
            reflect_on_all_attachments
              .select { |a| a.macro == :has_one_attached }
              .map(&:name)
          else
            []
          end
        end

        # Returns the names of has_many attached associations
        # @return [Array<Symbol>]
        def has_many_attached_field_names
          return @has_many_attached_field_names if defined?(@has_many_attached_field_names) && !Rails.env.local?

          @has_many_attached_field_names = if respond_to?(:reflect_on_all_attachments)
            reflect_on_all_attachments
              .select { |a| a.macro == :has_many_attached }
              .map(&:name)
          else
            []
          end
        end

        # Returns the names of content columns
        # @return [Array<Symbol>]
        def content_column_field_names
          return @content_column_field_names if defined?(@content_column_field_names) && !Rails.env.local?

          @content_column_field_names = content_columns.map { |col| col.name.to_sym }
        end

        # Returns the routes for has_many associations
        # @return [Array<Symbol>]
        def has_many_association_routes
          return @has_many_association_routes if defined?(@has_many_association_routes) && !Rails.env.local?

          @has_many_association_routes = reflect_on_all_associations(:has_many).map { |assoc| assoc.klass.model_name.plural }
        end

        # Returns all nested attributes options
        # @return [Hash]
        def all_nested_attributes_options
          unless Rails.env.local?
            return @all_nested_attributes_options if defined?(@all_nested_attributes_options)
          end

          @all_nested_attributes_options = reflect_on_all_associations.map do |association|
            setter_method = "#{association.name}_attributes="
            if method_defined?(setter_method)
              [association.name, nested_attributes_options[association.name].merge(
                macro: association.macro,
                class: association.polymorphic? ? nil : association.klass
              )]
            end
          end.compact.to_h
        end

        # Returns the strong parameters definition for the given attribute names
        # @param [Array<Symbol>] *attributes Attribute names
        # @return [Array<Symbol, Hash>] A strong parameters compatible array
        def strong_parameters_for(*attributes)
          unbacked = attributes - strong_parameters_definition.keys

          backed = strong_parameters_definition.slice(*attributes).values.reduce(:merge)
            &.map { |key, value| value.nil? ? key : {key => value} } || {}

          case backed.presence
          when Hash
            [*unbacked, **backed]
          when Array
            [*unbacked, *backed]
          when nil
            unbacked
          else
            raise "Unexpected strong parameters definition: #{backed.class}"
          end
        end

        # Finds the association to the given record
        # @param [ActiveRecord::Base] record The record to find the association with
        # @return [ActiveRecord::Reflection::AssociationReflection, nil]
        def find_association_to_record(record)
          reflect_on_all_associations.find do |assoc|
            assoc.klass.name == record.class.name
          rescue
            assoc.check_validity!
            raise
          end
        end

        # Finds the association to self in the given record
        # @param [ActiveRecord::Base] record The record to find the association with
        # @return [ActiveRecord::Reflection::AssociationReflection, nil]
        def find_association_to_self(record)
          record.class.reflect_on_all_associations.find do |assoc|
            assoc.klass.name == name
          rescue
            assoc.check_validity!
            raise
          end
        end

        # Queries based on the association type
        # @param [ActiveRecord::Reflection::AssociationReflection] assoc The association
        # @param [ActiveRecord::Base] record The record to query with
        # @return [ActiveRecord::Relation]
        def query_based_on_association(assoc, record)
          case assoc.macro
          when :has_one
            joins(assoc.name).where(assoc.name => {record.class.primary_key => record.id})
          when :belongs_to
            where(assoc.name => record)
          when :has_many
            joins(assoc.name).where(assoc.klass.table_name => record)
          else
            raise NotImplementedError, "associated_with->##{assoc.macro}"
          end
        end

        # Raises an error for unresolved associations
        # @param [ActiveRecord::Base] record The record with unresolved association
        # @param [Symbol] named_scope The named scope
        # @raise [RuntimeError]
        def raise_association_error(record, named_scope)
          raise "Could not resolve the association between '#{name}' and '#{record.class.name}'\n\n" \
                "Define\n" \
                " 1. the associations between the models\n" \
                " 2. a named scope on #{name} e.g.\n\n" \
                "scope :#{named_scope}, ->(#{record.model_name.singular}) { do_something_here }"
        end

        private

        # Defines the strong parameters
        # @return [Hash]
        def strong_parameters_definition
          unless Rails.env.local?
            return @strong_parameters if defined?(@strong_parameters)
          end

          @strong_parameters = build_strong_parameters
        end

        # Builds the strong parameters hash
        # @return [Hash]
        def build_strong_parameters
          parameters = content_column_field_names.map do |name|
            column = columns_hash[name.to_s]
            type = if column.try(:array?)
              []
            else
              ([:json, :jsonb].include?(column&.type) ? {} : nil)
            end
            [name, {name => type}]
          end.to_h

          parameters.merge!(belongs_to_association_parameters)
          parameters.merge!(has_many_association_parameters)
          parameters.merge!(attachment_parameters)
          parameters.merge!(nested_attributes_parameters)

          parameters
        end

        # Returns the parameters for belongs_to associations
        # @return [Hash]
        def belongs_to_association_parameters
          reflect_on_all_associations(:belongs_to).map do |reflection|
            input_param = reflection.options[:foreign_key] || :"#{reflection.name}_id"
            [reflection.name, {input_param => nil}]
          end.to_h
        end

        # Returns the parameters for has_many associations
        # @return [Hash]
        def has_many_association_parameters
          has_many_association_field_names.map do |name|
            [name, {"#{name.to_s.singularize}_ids": []}]
          end.to_h
        end

        # Returns the parameters for attachments
        # @return [Hash]
        def attachment_parameters
          has_many_attached_field_names.map { |name| [name, {name => []}] }.to_h
            .merge(has_one_attached_field_names.map { |name| [name, {name => nil}] }.to_h)
        end

        # Returns the parameters for nested attributes
        # @return [Hash]
        def nested_attributes_parameters
          all_nested_attributes_options.keys.map do |name|
            [name, {"#{name}_attributes" => {}}]
          end.to_h
        end

        # Defines a scope and method for path parameters
        # @param [Symbol] param_name The name of the parameter
        def path_parameter(param_name)
          param_name = param_name.to_sym

          scope :from_path_param, ->(param) { where(param_name => param) }

          define_method :to_param do
            return nil unless persisted?

            send(param_name)
          end
        end

        # Defines a scope and method for dynamic path parameters
        # @param [Symbol] param_name The name of the parameter
        def dynamic_path_parameter(param_name)
          param_name = param_name.to_sym

          scope :from_path_param, ->(param) { where(id: param.split("-").first) }

          define_method :to_param do
            return nil unless persisted?

            "#{id}-#{send(param_name)}".parameterize
          end
        end

        # Gathers all resource field names
        # @return [Array<Symbol>]
        def gather_resource_field_names
          belongs_to_association_field_names +
            has_one_attached_field_names +
            has_one_association_field_names +
            has_many_attached_field_names +
            has_many_association_field_names +
            content_column_field_names
        end
      end

      # Returns a label for the record
      # @return [String]
      def to_label
        %i[name title].each do |method|
          name = send(method) if respond_to?(method)
          return name if name.present?
        end

        "#{model_name.human} ##{to_param}"
      end
    end
  end
end
