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
  presents label: "Onboard an organization",
    description: "Set up a workspace for your team — a few quick steps and you're in."

  # Tokened/repeatable: a bare launch with pending runs shows the resume-or-new
  # chooser instead of silently forking (§4.5). This is the DEFAULT (`:prompt`),
  # so it needs no declaration — left implicit here on purpose to exercise it.

  step :identity, description: "Tell us who you are — this names the workspace." do
    attribute :name, :string
    attribute :plan, :string
    attribute :budget, :decimal
    # [label, value] pairs (label != value) so the review summary must resolve
    # the value ("pro") back to its label ("Pro"), not echo the raw value.
    input :plan, as: :select, choices: [["Free", "free"], ["Pro", "pro"], ["Enterprise", "enterprise"]]
    # A currency input (unit prefix on the form) — the review summary must render
    # it as currency ("$1,500.50"), not a bare decimal, even though the wizard
    # data snapshot carries no has_cents reflection.
    input :budget, as: :currency, unit: "$"
    validates :name, presence: true

    form_layout do
      section :basics, :name, :plan, :budget, label: "The basics"
    end
  end

  step :details, description: "Anything we should know? This is optional." do
    attribute :note, :string
    input :note, as: :textarea
  end

  # Import a field surface from a model (KitchenSink) — its <Model>Definition
  # overlays input styling (a :text/textarea and a :select), so we can assert the
  # imported fields render with their typed inputs, not plain text.
  step :profile, description: "A bit more about the account so we can tailor things.",
    using: KitchenSink, fields: [:description, :tier]

  # A repeatable structured input — must rehydrate N rows from staged data on GET.
  step :members, description: "Add teammates now — they'll get an email to join." do
    structured_input :invites, repeat: 5 do |f|
      f.input :email
      f.input :role
    end
  end

  # Custom content rendered after the auto-summary. The block runs in the Phlex
  # view context (`self` is the rendering component), so it may emit Phlex markup
  # (`div`, `render SomeComponent.new`, …) and reach view/route helpers via
  # `helpers.*`; it is yielded the wizard (→ `data`, `anchor`, `persisted`,
  # `current_user`). Returning a String — the simplest case — renders it as text.
  review label: "Review" do |wizard|
    "Ready to onboard #{wizard.data.identity.name}"
  end

  def execute
    org = Organization.create!(name: data.identity.name)
    succeed(org).with_message("Organization onboarded")
  end
end
