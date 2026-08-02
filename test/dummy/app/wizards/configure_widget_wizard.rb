# frozen_string_literal: true

# A hand-written ANCHORED dummy wizard (§3 / Fix A). Launched against an existing
# Widget through the resource-mounted member route
# (`/org/:org/widgets/:id/wizards/configure/:step`), so the anchor is resolved by
# the resource controller's scoped, policy-gated `resource_record!` — never an
# unscoped `find_by` (the IDOR fix). `execute` mutates THAT widget.
class ConfigureWidgetWizard < Plutonium::Wizard::Base
  presents label: "Configure widget"

  anchored with: Widget

  step :rename do
    attribute :name, :string
    # A proc-valued input option resolves against the wizard on every render, so
    # `anchor` reads here exactly as it does in `condition:` or `execute`.
    input :name, placeholder: -> { "Currently #{anchor.name}" }
    validates :name, presence: true

    # The case that motivated it: choices drawn from the anchor. Left optional so
    # the other tests can post this step without supplying it.
    attribute :rename_reason, :string
    input :rename_reason, as: :select, choices: -> { ["#{anchor.name} was wrong", "Other"] }
  end

  review label: "Review"

  def execute
    anchor.update!(name: data.rename.name)
    succeed(anchor).with_message("Widget configured")
  end
end
