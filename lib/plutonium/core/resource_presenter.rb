module Plutonium
  module Core
    module ResourcePresenter
      def initialize(context, resource_class)
        @context = context
        @resource_class = resource_class
      end

      def build_collection(permitted_attributes)
        fields = collection_fields & permitted_attributes

        customize_fields(Pu::UI::Builder::Collection.new(resource_class))
          .with_record_actions(build_actions.only!(*collection_record_actions))
          .with_actions(build_actions.only!(*collection_actions))
          .with_fields(fields)
      end

      def build_detail(permitted_attributes)
        fields = detail_fields & permitted_attributes

        customize_fields(Pu::UI::Builder::Detail.new(resource_class))
          .with_actions(build_actions.except!(:create, :show))
          .with_fields(fields)
      end

      def build_form(permitted_attributes)
        inputs = form_inputs & permitted_attributes

        customize_inputs(Pu::UI::Builder::Form.new(resource_class))
          .with_inputs(inputs)
      end

      def build_associations(permitted_associations)
        associations = associations_list & permitted_associations
        Pu::Builders::Associations.new
          .with_associations(associations)
      end

      def build_actions
        Pu::UI::Builder::Actions.new
          .with_standard_actions
      end

      private

      attr_reader :context, :resource_class

      def collection_fields
        raise NotImplementedError, "collection_fields"
      end

      def collection_actions
        %i[create]
      end

      def collection_record_actions
        %i[show edit destroy]
      end

      def detail_fields
        raise NotImplementedError, "detail_fields"
      end

      def form_inputs
        raise NotImplementedError, "form_inputs"
      end

      def associations_list
        raise NotImplementedError, "associations_list"
      end

      def customize_fields(builder)
        builder
      end

      def customize_inputs(builder)
        builder
      end
    end
  end
end
