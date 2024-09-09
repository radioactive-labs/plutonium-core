module Plutonium
  module Resource
    module Controllers
      module Presentable
        extend ActiveSupport::Concern

        included do
          helper_method :presentable_attributes, :present_associations?
        end

        private

        def presentable_attributes
          @presentable_attributes ||= begin
            presentable_attributes = permitted_attributes
            presentable_attributes -= [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"] if scoped_to_entity?
            presentable_attributes -= [parent_input_param, :"#{parent_input_param}_id"] if current_parent.present?
            presentable_attributes
          end
        end

        def build_collection
          current_definition.collection_class.new(@resource_records, resource_fields: presentable_attributes)
        end

        def build_detail
          current_definition.detail_class.new(resource_record, resource_fields: presentable_attributes, resource_associations: permitted_associations)
        end

        def build_form(record = resource_record)
          current_definition.form_class.new(record, resource_fields: presentable_attributes)
        end

        def present_associations?
          current_parent.nil?
        end
      end
    end
  end
end
