class OrgPortal::RbacRolesController < ::OrgPortal::ResourceController
  controller_for ::Plutonium::Rbac::Role

  include OrgPortal::Concerns::Controller

  private

  # Role#entity is polymorphic, which automatic entity scoping skips, so a role
  # created in a tenant portal is tied to that tenant here.
  def resource_params
    return super unless scoped_to_entity?

    super.merge(entity: current_scoped_entity)
  end
end
