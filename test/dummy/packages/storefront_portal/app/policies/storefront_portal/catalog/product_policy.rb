class StorefrontPortal::Catalog::ProductPolicy < ::Catalog::ProductPolicy
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

  def permitted_associations
    %i[]
  end

  def relation_scope(relation)
    default_relation_scope(relation).active
  end
end
