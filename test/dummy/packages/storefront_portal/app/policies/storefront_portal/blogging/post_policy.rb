class StorefrontPortal::Blogging::PostPolicy < ::Blogging::PostPolicy
  include StorefrontPortal::ResourcePolicy

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end

  # Custom actions inherited from Blogging::PostPolicy only check record
  # state, so a read-only public portal has to deny them explicitly.
  def publish? = false

  def archive? = false

  def touch? = false

  def permitted_associations
    %i[]
  end

  relation_scope do |relation|
    default_relation_scope(relation).published
  end
end
