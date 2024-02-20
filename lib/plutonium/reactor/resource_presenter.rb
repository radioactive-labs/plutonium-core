module Plutonium
  module Reactor
    class ResourcePresenter
      include Plutonium::Core::Definers::FieldDefiner
      include Plutonium::Core::Definers::ActionDefiner

      def initialize(context, resource_record)
        @context = context
        @resource_record = resource_record

        define_standard_actions
        define_actions
        define_fields
      end

      def search_field
        nil
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

      def resource_class = context.resource_class
    end
  end
end
