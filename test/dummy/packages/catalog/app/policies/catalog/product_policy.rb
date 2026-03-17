class Catalog::ProductPolicy < Catalog::ResourcePolicy
  def publish?
    record.is_a?(Catalog::Product) && record.draft?
  end

  def discontinue?
    record.is_a?(Catalog::Product) && record.active?
  end

  def permitted_attributes_for_create
    [:name, :description, :price, :status, :metadata, :category, :user, :organization]
  end

  def permitted_attributes_for_read
    [:name, :description, :price, :price_cents, :status, :metadata, :category, :user, :organization, :created_at]
  end

  def permitted_associations
    %i[variants product_detail reviews comments]
  end
end
