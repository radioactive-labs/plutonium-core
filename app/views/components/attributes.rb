module Plutonium
  module Ui
    module Attributes
      extend ActiveSupport::Concern

      # Provides methods for handling a base set of UI attributes.
      # The attributes include `id`, `data`, `classname`, `controllers`, and `tooltip`.
      #
      # @example Usage
      #    class MyComponent < Plutonium::Ui::Base
      #      include Plutonium::Ui::Attributes
      #      private
      #      # default set of attributes
      #      def base_attributes
      #        {
      #          id: "my-id",
      #          classname: "my-class", # classname can be an array or string
      #          controller: "my-controller",
      #          data: {
      #            key1: :value1,
      #            key2: :value2
      #          },
      #          custom_key1: :custom_value1,
      #          custom_key2: :custom_value2
      #        }
      #      end
      #    end
      #
      #    object = MyComponent.new(
      #      id: "my-preferred-id", # takes highest precedence, even over attributes hash
      #      classname: ["appended-class1", "appended-class2"], # appends to the class
      #      controllers: ["my-custom-controller"],
      #      # attributes hash allows us to override values set in base_attributes
      #      # hash is merged with attributes taking precedence
      #      attributes: {
      #        data: {
      #          key1: :overridden_value,
      #          key3: :attributes_value
      #        },
      #        custom_key1: :overridden_custom_value,
      #        attributes_custom_key1: :attributes_custom_value
      #      }
      #    )
      #    object.attributes_html
      #    # => id="my-preferred-id" class="my-class appended-class1 appended-class2" data-key1="overridden_value" data-key2="value2" data-key3="attributes_value" data-controller="my-controller my-custom-controller" custom_key1="overridden_custom_value" custom_key2="custom_value2" attributes_custom_key1="attributes_custom_value"

      included do
        option :id, optional: true
        # These will be merged with base_attributes
        option :data, default: proc { {} }
        option :classname, optional: true
        option :controllers, optional: true
        option :tooltip, optional: true
        # This will override values set in base_attributes
        option :attributes, default: proc { {} }
      end

      # Returns a memoized hash of attributes for the current object.
      #
      # The hash includes merged attributes from `base_attributes` and `attributes`,
      # and further processing is done to include specific fields like `id`,
      # `classname`, `controllers`, and `data`. The `data` field is enriched
      # with controller information.
      #
      # @return [Hash] The processed and merged attributes hash.
      #
      # @example Usage
      #   object = MyComponent.new
      #   attributes = object.attributes_hash
      #   # => { id: "some_id", title: "some_tooltip", class: "some_class", data: { controller: "some_controller", key: "value" } }
      def attributes_hash
        @attributes_hash ||= build_attributes_hash
      end

      # Generates an HTML-safe string of attributes for the current object.
      #
      # This method uses the `attributes_hash` method to get a hash of attributes
      # and then converts it into an HTML-safe string using the `tag` helper.
      #
      # @return [String] An HTML-safe string of attributes.
      #
      # @example Usage
      #   object = MyComponent.new
      #   html_attributes = object.attributes_html
      #   # => 'id="some_id" title="some_tooltip" class="some_class" data-controller="some_controller" data-key="value"'
      def attributes_html
        convert_attributes_to_html(attributes_hash)
      end

      private

      # Returns the base attributes for the object.
      # This can be overridden in subclasses to provide additional attributes.
      #
      # @return [Hash] The base attributes hash.
      def base_attributes
        {}
      end

      # Builds the attributes hash by merging base attributes and custom attributes,
      # and processing specific fields like id, classname, controllers, and data.
      #
      # @return [Hash] The processed and merged attributes hash.
      def build_attributes_hash
        merged_attributes = merge_base_and_custom_attributes
        {
          id: extract_id(merged_attributes),
          title: tooltip,
          class: extract_classname(merged_attributes),
          data: build_data(merged_attributes)
        }.deep_merge(merged_attributes).compact
      end

      # Merges base attributes with custom attributes.
      #
      # @return [Hash] The merged attributes.
      def merge_base_and_custom_attributes
        base_attributes.deep_merge(attributes)
      end

      # Extracts the id from the merged attributes or the current object.
      #
      # @param merged_attributes [Hash] The merged attributes hash.
      # @return [Object] The extracted id.
      def extract_id(merged_attributes)
        [id, merged_attributes.delete(:id)].compact.first
      end

      # Extracts and combines class names from merged attributes and the current object.
      #
      # @param merged_attributes [Hash] The merged attributes hash.
      # @return [String, nil] The combined class names.
      def extract_classname(merged_attributes)
        (Array(merged_attributes.delete(:classname)) + Array(classname)).compact.join(" ").presence
      end

      # Extracts and combines controller names from merged attributes and the current object.
      #
      # @param merged_attributes [Hash] The merged attributes hash.
      # @return [String, nil] The combined controller names.
      def extract_controllers(merged_attributes)
        (Array(merged_attributes.delete(:controller)) + Array(controllers)).compact.join(" ").presence
      end

      # Builds the data hash by merging data from merged attributes and the current object,
      # and adding controller information.
      #
      # @param merged_attributes [Hash] The merged attributes hash.
      # @return [Hash] The built data hash.
      def build_data(merged_attributes)
        data = (merged_attributes.delete(:data) || {}).merge(self.data)
        data[:controller] = extract_controllers(merged_attributes)
        data.compact!
        data
      end

      # Converts a hash of attributes to an HTML-safe string.
      #
      # @param attributes [Hash] The hash of attributes to convert.
      # @return [String] An HTML-safe string of attributes.
      def convert_attributes_to_html(attributes)
        tag.attributes(attributes)
      end
    end
  end
end
