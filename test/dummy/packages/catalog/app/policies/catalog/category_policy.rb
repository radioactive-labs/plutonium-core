class Catalog::CategoryPolicy < Catalog::ResourcePolicy
  def permitted_attributes_for_create
    [:name, :description, :parent]
  end

  def permitted_attributes_for_read
    [:name, :description, :parent]
  end

  def permitted_associations
    %i[subcategories products]
  end
end
