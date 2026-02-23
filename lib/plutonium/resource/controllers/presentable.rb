module Plutonium
  module Resource
    module Controllers
      module Presentable
        extend ActiveSupport::Concern

        included do
          helper_method :build_form, :build_detail, :build_collection
        end

        private

        def presentable_attributes
          @presentable_attributes ||= begin
            presentable_attributes = permitted_attributes
            if current_parent && !present_parent?
              presentable_attributes -= [parent_input_param, :"#{parent_input_param}_id"]
            end
            if scoped_to_entity? && !present_scoped_entity?
              presentable_attributes -= [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"]
            end
            presentable_attributes
          end
        end

        def submittable_attributes
          @submittable_attributes ||= submittable_attributes_for(action_name)
        end

        def submittable_attributes_for(action)
          submittable_attributes = permitted_attributes_for(action)
          if current_parent && !submit_parent?
            submittable_attributes -= [parent_input_param, :"#{parent_input_param}_id"]
          end
          if scoped_to_entity? && !submit_scoped_entity?
            submittable_attributes -= [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"]
          end
          submittable_attributes
        end

        def build_collection
          current_definition.collection_class.new(@resource_records, resource_fields: presentable_attributes, resource_definition: current_definition)
        end

        def build_detail
          current_definition.detail_class.new(resource_record!, resource_fields: presentable_attributes, resource_associations: permitted_associations, resource_definition: current_definition)
        end

        def build_form(record = resource_record!, action: action_name, form_action: nil, **)
          form_options = {
            resource_fields: submittable_attributes_for(action),
            resource_definition: current_definition,
            singular_resource: singular_resource_context?,
            **
          }
          form_options[:action] = form_action unless form_action.nil?
          current_definition.form_class.new(record, **form_options)
        end

        def present_parent? = false

        def present_scoped_entity? = false

        def submit_parent? = present_parent?

        def submit_scoped_entity? = present_scoped_entity?
      end
    end
  end
end
