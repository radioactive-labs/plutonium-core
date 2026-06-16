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
    input :name
    validates :name, presence: true
  end

  review label: "Review"

  def execute
    anchor.update!(name: data.rename.name)
    succeed(anchor).with_message("Widget configured")
  end
end
