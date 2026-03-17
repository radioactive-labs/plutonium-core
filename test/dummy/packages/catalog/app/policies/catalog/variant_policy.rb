class Catalog::VariantPolicy < Catalog::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:name, :sku, :price, :stock_count, :product]
  end

  def permitted_attributes_for_read
    [:name, :sku, :price, :stock_count, :product]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
