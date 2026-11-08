# Experimental: Plutonium RBAC. See https://radioactive-labs.github.io/plutonium-core/guides/rbac
#
# Who holds roles is ResourcePolicy#rbac_holder (app/policies/resource_policy.rb).

# System roles: synced to the database by `rails plutonium:rbac:sync`,
# read-only in the UI. Keys are "<resource>.<action>"; "*" grants everything.
Plutonium::Rbac.system_role :owner, name: "Owner", permissions: ["*"]
Plutonium::Rbac.system_role :member, name: "Member", permissions: []

# Permissions that are not a single resource action:
# Plutonium::Rbac.permission "reports.view", label: "View reports"
