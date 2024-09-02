module Plutonium
  module Resource
    module Controllers
      module Presentable
        extend ActiveSupport::Concern

        included do
          helper_method :presentable_attributes, :present_associations?
        end

        private

        def resource_presenter(resource_class, resource_record)
          presenter_class = "#{resource_class}Presenter".constantize
          presenter_class.new resource_context, resource_record
        end

        def current_presenter
          @current_presenter ||= resource_presenter resource_class, @resource_record
        end

        def presentable_attributes
          @presentable_attributes ||= begin
            presentable_attributes = permitted_attributes
            presentable_attributes -= [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"] if scoped_to_entity?
            presentable_attributes -= [parent_input_param, :"#{parent_input_param}_id"] if current_parent.present?
            presentable_attributes
          end
        end

        def build_collection
          current_definition.collection_class.new @resource_records, resource_fields: presentable_attributes
        end

        def build_detail
          Plutonium::Core::UI::Detail.new(
            resource_class:,
            record: resource_record,
            fields: current_presenter.defined_field_renderers_for(*presentable_attributes),
            associations: current_presenter.defined_association_renderers_for(*permitted_associations),
            actions: current_presenter.actions
          )
        end

        def build_form(record = resource_record)
          # preferred_action_after_submit:
          current_definition.form_class.new(record, resource_fields: presentable_attributes)
        end

        def present_associations?
          current_parent.nil?
        end
      end
    end
  end
end
