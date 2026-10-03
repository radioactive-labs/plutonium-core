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

  # Custom actions inherited from Catalog::ProductPolicy only check record
  # state, so a read-only public portal has to deny them explicitly.
  def publish? = false

  def discontinue? = false

  def collect_spec? = false

  def collect_spec_row? = false

  def assign_reviewer? = false

  def conditioned_select? = false

  def draft_only_demo? = false

  def param_gated_demo? = false

  def permitted_associations
    %i[]
  end

  relation_scope do |relation|
    default_relation_scope(relation).active
  end
end
