class OrgPortal::UserPolicy < ::UserPolicy
  include OrgPortal::ResourcePolicy

  # org_portal registers User as a SINGULAR resource (`resource :user`), and a
  # singular route carries no :id — the scope is the identification. So the scope
  # has to resolve to exactly one record, which the base policy's entity scope
  # (every member of the org) does not. Without this, /user is an arbitrary
  # member and every /user/nested_* route raises Plutonium::SingularScopeError.
  #
  # Narrowed to the viewer, which is what a singular User in a tenant portal
  # means anyway: "my account here", not "some member".
  relation_scope do |relation|
    default_relation_scope(relation).where(id: user.id)
  end
end
