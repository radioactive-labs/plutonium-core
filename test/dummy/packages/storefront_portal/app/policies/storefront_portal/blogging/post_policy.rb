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

  def permitted_associations
    %i[]
  end

  relation_scope do |relation|
    default_relation_scope(relation).published
  end
end
