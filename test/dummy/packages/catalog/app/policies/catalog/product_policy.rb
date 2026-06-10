class Catalog::ProductPolicy < Catalog::ResourcePolicy
  def publish?
    record.is_a?(Catalog::Product) && record.draft?
  end

  def discontinue?
    record.is_a?(Catalog::Product) && record.active?
  end

  def collect_spec?
    record.is_a?(Catalog::Product)
  end

  def collect_spec_row?
    record.is_a?(Catalog::Product)
  end

  def assign_reviewer?
    record.is_a?(Catalog::Product)
  end

  def conditioned_select?
    record.is_a?(Catalog::Product)
  end

  # Always permitted by policy; visibility is governed entirely by each
  # action's `condition:` proc, exercising the separation between
  # authorization (policy) and display-only conditions.
  def draft_only_demo?
    record.is_a?(Catalog::Product)
  end

  def param_gated_demo?
    record.is_a?(Catalog::Product)
  end

  def permitted_attributes_for_create
    [:name, :description, :price, :status, :featured, :metadata, :category, :user, :organization, :variants, :product_detail, :tier]
  end

  def permitted_attributes_for_read
    [:name, :description, :price, :price_cents, :status, :featured, :metadata, :category, :user, :organization, :created_at]
  end

  def permitted_associations
    %i[variants product_detail reviews comments]
  end
end
