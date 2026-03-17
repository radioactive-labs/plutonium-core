class StorefrontPortal::Catalog::CategoryPolicy < ::Catalog::CategoryPolicy
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
    %i[subcategories]
  end
end
