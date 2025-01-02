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
        @name = [main_app? ? nil : selected_destination_feature.underscore, super.singularize.underscore].compact.join "/"
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
          name, type, index_type = column_definition.split(":")

          # if user provided "name:index" instead of "name:string:index"
          # type should be set blank so GeneratedAttribute's constructor
          # could set it to :string
          index_type, type = type, nil if valid_index_type?(type)

          type, attr_options = *parse_type_and_options(type)
          type = type.to_sym if type

          if dangerous_name?(name)
            raise Error, "Could not generate field '#{name}', as it is already defined by Active Record."
          end

          if type && !valid_type?(type)
            raise Error, "Could not generate field '#{name}' with unknown type '#{type}'."
          end

          if index_type && !valid_index_type?(index_type)
            raise Error, "Could not generate field '#{name}' with unknown index '#{index_type}'."
          end

          if type && reference?(type)
            if Rails::Generators::GeneratedAttribute::UNIQ_INDEX_OPTIONS.include?(index_type)
              attr_options[:index] = {unique: true}
            end

            if name.include? "/"
              attr_options[:to_table] = name.tr("/", "_").pluralize.to_sym
              attr_options[:class_name] = name.classify
              if (shared_namespace = find_shared_namespace(model_name, name, separator: "/"))
                name = name.sub "#{shared_namespace}/", ""
              end

              name = name.tr "/", "_"
            end
          end

          new(name, type, index_type, attr_options)
        end

        private

        def parse_type_and_options(type)
          parsed_type, parsed_options = super

          if type&.ends_with?("?")
            parsed_type.remove!("?")
            parsed_options[:null] = true
          end

          [parsed_type, parsed_options]
        end

        private

        def find_shared_namespace(model1, model2, separator: "::")
          # Split the model names by separator to get the namespaces and class names as arrays
          parts1 = model1.split(separator)
          parts2 = model2.split(separator)

          # Initialize an array to hold the shared namespace parts
          shared_namespace = []

          # Iterate over the shorter of the two arrays
          [parts1.length, parts2.length].min.times do |i|
            if parts1[i] == parts2[i]
              shared_namespace << parts1[i]
            else
              break
            end
          end

          # Return the shared namespace, joined by '::' or nil if there's no shared namespace
          shared_namespace.empty? ? nil : shared_namespace.join(separator)
        end
      end

      def required?
        super || attr_options[:null] != true
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
