# frozen_string_literal: true

# A CONTEXT-anchored, portal-level wizard (§3 `anchored via:`). Mounted with
# `register_wizard` in the entity-scoped org portal; its anchor is resolved by
# calling `current_scoped_entity` on the controller (the tenant Organization) —
# no URL `:id`, IDOR-safe. `concurrency_key { anchor }` keys one in-progress run
# per organization, and `one_time` retains the completed marker (gateable).
class ConfigureOrgWizard < Plutonium::Wizard::Base
  presents label: "Configure organization"

  anchored via: :current_scoped_entity, with: Organization

  concurrency_key { anchor }
  one_time

  step :rename do
    attribute :name, :string
    input :name
    validates :name, presence: true
  end

  review label: "Review"

  def execute
    anchor.update!(name: data.name)
    succeed(anchor).with_message("Organization configured")
  end
end
