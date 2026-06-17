# frozen_string_literal: true

# Exercises the author-control options on the wizard chrome (Task: form control):
#   - `stepper false`         → no top rail rendered
#   - `review summary: false` with NO custom block → the built-in "ready to
#     complete" panel renders in the COMPLETE state (instead of the auto-summary)
#   - `review header: false`  → no step-header section (label + prompt) on review
#
# A tiny single-step create flow so the integration test can reach review in one
# POST.
class ChromelessWizard < Plutonium::Wizard::Base
  presents label: "Chromeless"

  stepper false

  step :only, description: "Just one field." do
    attribute :name, :string
    input :name
    validates :name, presence: true
  end

  review label: "Done", summary: false, header: false

  def execute
    succeed.with_message("Done")
  end

  # Portal-level wizard with no resource policy — gate it to authenticated users.
  def authorize? = current_user.present?
end
