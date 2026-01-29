class DemoFeatures::ProductPolicy < DemoFeatures::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:name, :sku, :slug, :description, :notes, :stock_count, :weight, :price, :compare_at_price, :active, :featured, :taxable, :release_date, :discontinue_date, :last_restocked_at, :published_at, :available_from_time, :available_until_time, :metadata, :specifications, :status, :category, :variants]
  end

  def permitted_attributes_for_read
    [:name, :sku, :slug, :description, :notes, :stock_count, :weight, :price, :compare_at_price, :active, :featured, :taxable, :release_date, :discontinue_date, :last_restocked_at, :published_at, :available_from_time, :available_until_time, :metadata, :specifications, :status, :category]
  end

  # Associations

  def permitted_associations
    %i[variants]
  end
end
