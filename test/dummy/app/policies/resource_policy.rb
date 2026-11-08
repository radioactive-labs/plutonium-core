class ResourcePolicy < Plutonium::Resource::Policy
  def create?
    true
  end

  def read?
    true
  end

  # Who holds roles for `user` in `entity_scope`. nil means no permissions.
  def rbac_holder
    OrganizationUser.find_by(user:, organization: entity_scope) if entity_scope
  end
end
