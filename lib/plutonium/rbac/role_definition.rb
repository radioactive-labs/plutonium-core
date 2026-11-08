# frozen_string_literal: true

module Plutonium
  module Rbac
    # The UI configuration for role records. Found by convention
    # ("#{resource_class}Definition"); portals override with
    # MyPortal::Plutonium::Rbac::RoleDefinition.
    class RoleDefinition < Plutonium::Resource::Definition
      # `permissions` is a JSON column, so nothing infers the grid.
      # Role derives a blank key from the name, so the form must not insist on it.
      field :key, required: false, hint: t("plutonium.rbac.role.key_hint")
      input :permissions, as: :rbac_permissions
      display :permissions, as: :rbac_permissions
    end
  end
end
