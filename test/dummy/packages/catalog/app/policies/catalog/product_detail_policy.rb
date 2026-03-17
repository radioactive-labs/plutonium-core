class Catalog::ProductDetailPolicy < Catalog::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:specifications, :warranty_info, :product]
  end

  def permitted_attributes_for_read
    [:specifications, :warranty_info, :product]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
