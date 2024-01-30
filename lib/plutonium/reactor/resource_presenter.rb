module Plutonium
  module Reactor
    class ResourcePresenter
      include Plutonium::Core::Presenters::FieldDefinitions

      def initialize(context)
        @context = context

        customize_fields
      end

      def build_collection(permitted_attributes)
        Plutonium::UI::Builder::Collection.new(context.resource_class)
          .with_record_actions(build_actions.only!(*collection_record_actions))
          .with_actions(build_actions.only!(*collection_actions))
          .with_fields(field_renderers_for permitted_attributes)
      end

      def build_detail(permitted_attributes)
        fields = detail_fields & permitted_attributes

        Plutonium::UI::Builder::Detail.new(context.resource_class)
          .with_actions(build_actions.except!(:create, :show))
          .with_fields(field_renderers_for fields)
      end

      def build_form(permitted_attributes)
        inputs = field_inputs_for(form_inputs & permitted_attributes)
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

      def autodetect_fields_for(method_name)
        maybe_warn_autodetect_usage method_name

        belongs_to = context.resource_class.reflect_on_all_associations(:belongs_to).map { |col| col.name.to_sym }
        has_many = context.resource_class.reflect_on_all_associations(:has_many).map { |col| col.name.to_sym }
        content_columns = context.resource_class.content_columns.map { |col| col.name.to_sym }
        belongs_to + content_columns + has_many
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

      def customize_fields
        # do nothing
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
