# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record/model/model_generator"

module PlutoniumGenerators
  class ModelGeneratorBase < ActiveRecord::Generators::ModelGenerator
    include PlutoniumGenerators::Generator

    remove_hook_for :test_framework
    remove_task :create_migration_file
    remove_task :create_model_file
    remove_task :create_module_file
    # remove_task :check_class_collision

    # def check_class_collision # :doc:
    #   class_collisions "#{options[:prefix]}#{name}#{options[:suffix]}"
    # end

    private

    def parse_attributes!
      @original_attributes = attributes
      self.attributes = parse_attributes_internal!(attributes)
    end

    def parse_attributes_internal!(attributes)
      (attributes || []).map do |attr|
        GeneratedAttribute.parse(name, attr)
      end
    end

    # def class_collisions(*class_names)
    #   super
    # rescue Rails::Generators::Error
    #   raise
    # end

    def name
      @pu_name ||= begin
        @original_name = @name
        resource_name = super.singularize.underscore
        dest_namespace = main_app? ? nil : selected_destination_feature.underscore
        # Strip destination namespace from resource name if already present
        if dest_namespace && resource_name.start_with?("#{dest_namespace}/")
          resource_name = resource_name.sub("#{dest_namespace}/", "")
        end
        @name = [dest_namespace, resource_name].compact.join "/"
        set_destination_root!
        @name
      end
    end

    def feature_package_name
      main_app? ? nil : selected_destination_feature.camelize
    end

    def main_app?
      selected_destination_feature == "main_app"
    end

    def selected_destination_feature
      feature_option :dest, prompt: "Select destination feature"
    end

    def set_destination_root!
      @destination_stack = [File.join(Rails.root, main_app? ? "" : "packages/#{selected_destination_feature.underscore}")]
    end

    # https://github.com/rails/rails/blob/main/railties/lib/rails/generators/generated_attribute.rb#L7
    class GeneratedAttribute < Rails::Generators::GeneratedAttribute
      class << self
        def parse(model_name, column_definition)
          # Protect content inside {} from being split on colons
          # e.g., "status:string{default:draft}" -> split correctly
          options_content = nil
          if column_definition.include?("{")
            column_definition = column_definition.gsub(/\{([^}]*)\}/) do |match|
              options_content = $1
              "{OPTIONS}"
            end
          end

          name, type, index_type = column_definition.split(":")

          # Restore options content
          type = type&.sub("{OPTIONS}", "{#{options_content}}") if options_content

          # if user provided "name:index" instead of "name:string:index"
          # type should be set blank so GeneratedAttribute's constructor
          # could set it to :string
          index_type, type = type, nil if valid_index_type?(type)

          type, attr_options = *parse_type_and_options(type)
          type = type.to_sym if type

          if dangerous_name?(name)
            raise "Could not generate field '#{name}', as it is already defined by Active Record."
          end

          if type && !valid_type?(type)
            raise "Could not generate field '#{name}' with unknown type '#{type}'."
          end

          if index_type && !valid_index_type?(index_type)
            raise "Could not generate field '#{name}' with unknown index '#{index_type}'."
          end

          if type && reference?(type)
            if Rails::Generators::GeneratedAttribute::UNIQ_INDEX_OPTIONS.include?(index_type)
              attr_options[:index] = {unique: true}
            end

            if name.include? "/"
              attr_options[:to_table] = name.underscore.tr("/", "_").pluralize.to_sym
              attr_options[:class_name] = name.classify
              name = name.underscore
              if (shared_namespace = find_shared_namespace(model_name, name, separator: "/"))
                name = name.sub("#{shared_namespace}/", "")
              end
              name = name.tr("/", "_")
            end
          end

          new(name, type, index_type, attr_options)
        end

        private

        # Extends Rails' parse_type_and_options to support:
        # - nullable types with ? suffix: 'string?' -> null: true
        # - default values: 'string{default:value}' -> default: "value"
        # - class_name for references: 'belongs_to{class_name:User}' -> class_name: "User"
        def parse_type_and_options(type)
          nullable = type&.include?("?")
          type = type&.sub("?", "") if nullable

          # Extract custom options before calling super
          # Syntax: type{option:value} or type{limit,option:value}
          default_value = nil
          class_name_value = nil

          if type&.include?("{")
            # Extract default:value
            if (match = type.match(/\{([^}]*default:([^,}]+)[^}]*)\}/))
              default_value = match[2]
              type = remove_option_from_type(type, "default", default_value)
            end

            # Extract class_name:Value
            if (match = type.match(/\{([^}]*class_name:([^,}]+)[^}]*)\}/))
              class_name_value = match[2]
              type = remove_option_from_type(type, "class_name", class_name_value)
            end
          end

          parsed_type, parsed_options = super

          parsed_options[:null] = nullable ? true : false
          parsed_options[:default] = coerce_default_value(default_value, parsed_type) if default_value
          if class_name_value
            parsed_options[:class_name] = class_name_value
            parsed_options[:to_table] = class_name_value.underscore.tr("/", "_").pluralize.to_sym
          end

          [parsed_type, parsed_options]
        end

        def remove_option_from_type(type, option_name, option_value)
          escaped_value = Regexp.escape(option_value)
          type.gsub(/\{[^}]*\}/) do |match|
            content = match[1..-2] # Remove { and }
            cleaned = content
              .gsub(/,?\s*#{option_name}:#{escaped_value}/, "")
              .gsub(/#{option_name}:#{escaped_value},?\s*/, "")
            cleaned.empty? ? "" : "{#{cleaned}}"
          end
        end

        def coerce_default_value(value, type)
          case type&.to_s
          when "integer"
            value.to_i
          when "float", "decimal"
            value.to_f
          when "boolean"
            %w[true 1 yes].include?(value.downcase)
          else
            value
          end
        end

        def find_shared_namespace(model1, model2, separator: "::")
          parts1 = model1.underscore.split(separator)
          parts2 = model2.underscore.split(separator)

          shared_namespace = []
          [parts1.length, parts2.length].min.times do |i|
            if parts1[i] == parts2[i]
              shared_namespace << parts1[i]
            else
              break
            end
          end

          shared_namespace.empty? ? nil : shared_namespace.join(separator)
        end
      end

      def required?
        return false if attr_options[:null] == true

        super
      end

      def cents?
        type == :integer && name.ends_with?("_cents")
      end

      def attribute_name
        if cents?
          name.sub("_cents", "")
        else
          name
        end
      end

      def options_for_migration
        super.tap do |options|
          if options[:to_table]
            options[:foreign_key] = {to_table: options.delete(:to_table)}
          end
          options.delete(:class_name)
        end
      end
    end
  end
end
