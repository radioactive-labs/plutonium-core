# See AdminPortal::InteractionRunsController for why the controller is not named
# after its resource. OrgPortal is `:path` entity-scoped, so this is also what
# proves a run's URL carries the tenant and that one tenant cannot read
# another's runs.
class OrgPortal::InteractionRunsController < OrgPortal::ResourceController
  controller_for ::Plutonium::Interaction::Run
end
