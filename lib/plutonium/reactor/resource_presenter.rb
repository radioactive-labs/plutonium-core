module Plutonium
  module Reactor
    class ResourcePresenter
      def initialize(context, resource_class)
        @context = context
        @resource_class = resource_class
      end

      def build_collection(permitted_attributes)
        fields = collection_fields & permitted_attributes

        customize_fields(Plutonium::UI::Builder::Collection.new(resource_class))
          .with_record_actions(build_actions.only!(*collection_record_actions))
          .with_actions(build_actions.only!(*collection_actions))
          .with_fields(fields)
      end

      def build_detail(permitted_attributes)
        fields = detail_fields & permitted_attributes

        customize_fields(Plutonium::UI::Builder::Detail.new(resource_class))
          .with_actions(build_actions.except!(:create, :show))
          .with_fields(fields)
      end

      def build_form(permitted_attributes)
        inputs = form_inputs & permitted_attributes

        customize_inputs(Plutonium::UI::Builder::Form.new(resource_class))
          .with_inputs(inputs)
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

      attr_reader :context, :resource_class

      def collection_fields
        maybe_warn_autodetect_usage :collection_fields
        context.resource_class.columns.map { |col| col.name.to_sym } - %i[id]
        # raise NotImplementedError, "collection_fields"
      end

      def collection_actions
        %i[create]
      end

      def collection_record_actions
        %i[show edit destroy]
      end

      def detail_fields
        maybe_warn_autodetect_usage :detail_fields
        context.resource_class.columns.map { |col| col.name.to_sym } - %i[id]
      end

      def form_inputs
        maybe_warn_autodetect_usage :form_inputs
        context.resource_class.columns.map { |col| col.name.to_sym }
      end

      def associations_list
        maybe_warn_autodetect_usage :collection_fields
        []
      end

      def customize_fields(builder)
        builder
      end

      def customize_inputs(builder)
        builder
      end

      def maybe_warn_autodetect_usage(method)
        return unless Rails.env.production?

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
