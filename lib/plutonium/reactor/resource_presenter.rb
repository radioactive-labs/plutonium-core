module Plutonium
  module Reactor
    class ResourcePresenter
      include Plutonium::Core::Presenters::FieldDefinitions
      include Plutonium::Core::Presenters::ActionDefinitions

      def initialize(context)
        @context = context

        define_standard_actions
        define_actions
        define_fields
      end

      private

      attr_reader :context

      def define_fields
        # override this in child presenters for custom field definitions
      end

      def define_actions
        # override this in child presenters for custom action definitions
      end

      def define_standard_actions
        define_action :new, Plutonium::Core::Actions::NewAction.new(:new)
        define_action :show, Plutonium::Core::Actions::ShowAction.new(:show)
        define_action :edit, Plutonium::Core::Actions::EditAction.new(:edit)
        define_action :destroy, Plutonium::Core::Actions::DestroyAction.new(:destroy)
      end

      # def maybe_warn_autodetect_usage(method)
      #   return if Rails.env.local?

      #   Rails.logger.warn %(
      #     🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨

      #     Resource field auto-detection violation #{self.class}##{method}

      #     Using auto-detected resource fields in production is not recommended.
      #     It can lead to accidental exposure of sensitive resource fields.

      #     Override a #{context.resource_class}Presenter with your own ##{method} method.

      #     🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
      #   )
      # end
    end
  end
end
