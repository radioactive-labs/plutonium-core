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
              presentable_attributes -= scoped_entity_field_names
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
            submittable_attributes -= scoped_entity_field_names
          end
          submittable_attributes
        end

        # Returns all field names related to the scoped entity.
        # Finds associations by class to handle cases where param_key differs from association name.
        def scoped_entity_field_names
          field_names = [scoped_entity_param_key, :"#{scoped_entity_param_key}_id"]

          assoc_name = scoped_entity_association
          if assoc_name
            field_names << assoc_name
            field_names << :"#{assoc_name}_id"
          end

          field_names.uniq
        end

        # Returns the name of the belongs_to association pointing to the scoped entity class.
        # Raises if multiple associations exist (ambiguous - user must configure manually).
        # @return [Symbol, nil] the association name or nil if not found
        def scoped_entity_association
          return @scoped_entity_association if defined?(@scoped_entity_association)

          matching_assocs = resource_class.reflect_on_all_associations(:belongs_to).select do |assoc|
            assoc.klass.name == scoped_entity_class.name
          rescue NameError
            false
          end

          if matching_assocs.size > 1
            assoc_names = matching_assocs.map(&:name).join(", ")
            raise <<~MSG.squish
              #{resource_class} has multiple associations to #{scoped_entity_class}: #{assoc_names}.
              Plutonium cannot auto-detect which one to use for entity scoping.
              Override `scoped_entity_association` in your controller to specify the association.
            MSG
          end

          @scoped_entity_association = matching_assocs.first&.name
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
