class DemoFeatures::VariantPolicy < DemoFeatures::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:product, :name, :sku, :price, :stock_count, :active, :options]
  end

  def permitted_attributes_for_read
    [:product, :name, :sku, :price, :stock_count, :active, :options]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
