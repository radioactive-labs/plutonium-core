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

      def build_form(permitted_attributes)
        inputs = inputs_for(form_inputs & permitted_attributes)
        Plutonium::UI::Builder::Form.new.with_inputs(inputs)
      end

      def build_associations(permitted_associations)
        associations = associations_list & permitted_associations
        Plutonium::Builders::Associations.new
          .with_associations(associations)
      end

      def build_actions
        Plutonium::UI::Builder::Actions.new
          .with_standard_actions
      end

      private

      attr_reader :context

      def define_standard_actions
        define_action :new, Plutonium::Core::Actions::NewAction.new(:new)
        define_action :show, Plutonium::Core::Actions::ShowAction.new(:show)
        define_action :edit, Plutonium::Core::Actions::EditAction.new(:edit)
        define_action :destroy, Plutonium::Core::Actions::DestroyAction.new(:destroy)
      end

      def define_fields
        # override this in child presenters for custom field definitions
      end

      def define_actions
        # override this in child presenters for custom action definitions
      end

      def autodetect_fields_for(method_name)
        maybe_warn_autodetect_usage method_name

        context.resource_class.resource_fields
      end

      def collection_fields
        autodetect_fields_for :collection_fields
      end

      def collection_actions
        %i[create]
      end

      def collection_record_actions
        %i[show edit destroy]
      end

      def detail_fields
        autodetect_fields_for :detail_fields
      end

      def form_inputs
        autodetect_fields_for :form_inputs
      end

      def associations_list
        maybe_warn_autodetect_usage :collection_fields
        []
      end

      def maybe_warn_autodetect_usage(method)
        return if Rails.env.local?

        Rails.logger.warn %(
          🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨

          Resource field auto-detection violation #{self.class}##{method}

          Using auto-detected resource fields in production is not recommended.
          It can lead to accidental exposure of sensitive resource fields.

          Override a #{context.resource_class}Presenter with your own ##{method} method.

          🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
        )
      end
    end
  end
end
