# frozen_string_literal: true

# A hand-written dummy wizard (authored like an interaction) exercising the
# portal-hosted controller + register_wizard routing AND the real step-form UI
# (Task 6) in integration tests.
#
# Non-anchored create flow:
#   identity  → a name (text) + a plan (select), with an inline form_layout
#   details   → a note (textarea), imported styling from a using: model
#   profile   → fields imported from KitchenSink (textarea + select) via using:
#   members   → a repeatable structured_input (exercises repeater rehydration)
#   review    → auto-summary + gated finish + a custom block
#
# `execute` creates an Organization atomically.
class OnboardOrganizationWizard < Plutonium::Wizard::Base
  presents label: "Onboard an organization"

  step :identity do
    attribute :name, :string
    attribute :plan, :string
    input :name
    input :plan, as: :select, choices: %w[free pro enterprise]
    validates :name, presence: true

    form_layout do
      section :basics, :name, :plan, label: "The basics"
    end
  end

  step :details do
    attribute :note, :string
    input :note, as: :textarea
  end

  # Import a field surface from a model (KitchenSink) — its <Model>Definition
  # overlays input styling (a :text/textarea and a :select), so we can assert the
  # imported fields render with their typed inputs, not plain text.
  step :profile, using: KitchenSink, fields: [:description, :tier]

  # A repeatable structured input — must rehydrate N rows from staged data on GET.
  step :members do
    structured_input :invites, repeat: 5 do |f|
      f.input :email
      f.input :role
    end
  end

  review label: "Review" do |wizard|
    # A custom block on the review step (rendered after the auto-summary).
    "Ready to onboard #{wizard.data.name}"
  end

  def execute
    org = Organization.create!(name: data.name)
    succeed(org).with_message("Organization onboarded")
  end
end
