class Catalog::ProductPolicy < Catalog::ResourcePolicy
  def publish? = record.draft?

  def discontinue? = record.active?

  def collect_spec? = true

  def collect_spec_row? = true

  def assign_reviewer? = true

  def conditioned_select? = true

  # Always permitted by policy; visibility is governed entirely by each
  # action's `condition:` proc, exercising the separation between
  # authorization (policy) and display-only conditions.
  def draft_only_demo? = true

  def param_gated_demo? = true

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
