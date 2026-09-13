# Registered on the entity-scoped org portal: every card runs inside the
# tenant, so `current_scoped_entity` is the organization in the URL.
class TeamDashboard < Plutonium::Dashboard::Base
  presents label: "Team"

  metric(:members) { current_scoped_entity.organization_users.count }

  card(:name) { p { current_scoped_entity.name } }
end
