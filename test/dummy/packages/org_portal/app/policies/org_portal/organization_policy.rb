class OrgPortal::OrganizationPolicy < ::OrganizationPolicy
  include OrgPortal::ResourcePolicy

  # org_portal registers Organization as a (mostly routing-only) singular
  # resource and does NOT register OrganizationUser, so the base policy's
  # `%i[organization_users users]` would render association tabs pointing
  # at unregistered resources and raise. Member management lives in
  # admin_portal; here the org's self-view just shows its own fields.
  def permitted_associations
    []
  end
end
