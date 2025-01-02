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
            if current_parent
              presentable_attributes -= [parent_input_param, :"#{parent_input_param}_id"]
            elsif scoped_to_entity?
              presentable_attributes -= [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"]
            end
            presentable_attributes
          end
        end

        def submittable_attributes
          @submittable_attributes ||= begin
            submittable_attributes = permitted_attributes
            submittable_attributes -= [parent_input_param, :"#{parent_input_param}_id"] if current_parent
            submittable_attributes -= [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"] if scoped_to_entity?
            submittable_attributes
          end
        end

        def build_collection
          current_definition.collection_class.new(@resource_records, resource_fields: presentable_attributes, resource_definition: current_definition)
        end

        def build_detail
          current_definition.detail_class.new(resource_record!, resource_fields: presentable_attributes, resource_associations: permitted_associations, resource_definition: current_definition)
        end

        def build_form(record = resource_record!)
          current_definition.form_class.new(record, resource_fields: submittable_attributes, resource_definition: current_definition)
        end
      end
    end
  end
end
