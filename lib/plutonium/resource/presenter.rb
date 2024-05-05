module Plutonium
  module Resource
    class Presenter
      include Plutonium::Core::Definers::FieldDefiner
      include Plutonium::Core::Definers::ActionDefiner

      def initialize(context, resource_record)
        @context = context
        @resource_record = resource_record

        define_standard_actions
        define_actions
        define_fields
      end

      private

      attr_reader :context, :resource_record

      def define_fields
        # override this in child presenters for custom field definitions
      end

      def define_actions
        # override this in child presenters for custom action definitions
      end

      def define_standard_actions
        define_action Plutonium::Core::Actions::NewAction.new(:new)
        define_action Plutonium::Core::Actions::ShowAction.new(:show)
        define_action Plutonium::Core::Actions::EditAction.new(:edit)
        define_action Plutonium::Core::Actions::DestroyAction.new(:destroy)
      end

      # TODO: move this to its own definer
      def define_interactive_action(name, interaction:, **)
        define_action Plutonium::Core::Actions::InteractiveAction.new(name, interaction:, **)
      end

      # TODO: move this to its own definer
      def define_nested_input(name, inputs:, model_class: nil, **options)
        nested_attribute_options = resource_class.all_nested_attributes_options[name]

        nested_attribute_options_class = nested_attribute_options&.[](:class)
        if nested_attribute_options_class.nil? && model_class.nil?
          raise ArgumentError, "model_class is required if your field is not an association or is polymorphic"
        end
        model_class ||= nested_attribute_options_class

        macro = nested_attribute_options&.[](:macro)
        allow_destroy = nested_attribute_options&.[](:allow_destroy).presence
        update_only = nested_attribute_options&.[](:update_only).presence
        limit = if macro == :has_one
          1
        elsif options.key?(:limit)
          options[:limit]
        else
          nested_attribute_options&.[](:limit)
        end

        input = Plutonium::Core::Fields::Inputs::NestedInput.new(
          name,
          inputs:,
          allow_destroy: options.key?(:allow_destroy) ? options[:allow_destroy] : allow_destroy,
          update_only: options.key?(:update_only) ? options[:update_only] : update_only,
          limit: limit,
          resource_class: model_class,
          **options
        )
        yield input if block_given?

        define_input name, input:
      end

      def resource_class = context.resource_class
    end
  end
end
