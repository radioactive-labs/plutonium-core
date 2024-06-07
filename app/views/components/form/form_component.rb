module PlutoniumUi
  class FormComponent < PlutoniumUi::Base
    option :form
    option :preferred_action_after_submit, default: proc { "show" }

    private

    def supported_actions_after_submit
      %w[show edit new index]
    end

    def action_after_submit_label(action)
      {
        "show" => "and view details",
        "edit" => "and continue editing",
        "new" => "and add another",
        "index" => "and view all"
      }[action]
    end
  end
end

Plutonium::ComponentRegistry.register :form, to: PlutoniumUi::FormComponent
