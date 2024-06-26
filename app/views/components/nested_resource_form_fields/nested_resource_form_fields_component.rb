module PlutoniumUi
  class NestedResourceFormFieldsComponent < PlutoniumUi::Base
    option :name
    option :resource_class
    option :form
    option :inputs
    option :label, optional: true
    option :description, optional: true
    option :allow_destroy, optional: true
    option :update_only, optional: true
    option :limit, optional: true

    def base_attributes
      {
        classname: "mt-6 mb-4",
        controller: "nested-resource-form-fields",
        data: {
          "nested-resource-form-fields-limit-value": limit
        }
      }
    end

    def label
      super || name.to_s.humanize
    end
  end
end

Plutonium::ComponentRegistry.register :nested_resource_form_fields, to: PlutoniumUi::NestedResourceFormFieldsComponent
