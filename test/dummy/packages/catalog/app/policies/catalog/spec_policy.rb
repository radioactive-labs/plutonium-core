class Catalog::SpecPolicy < Catalog::ResourcePolicy
  def permitted_attributes_for_create
    [:payload, :rows, :meta, :items]
  end

  def permitted_attributes_for_read
    [:payload, :rows, :meta, :items, :created_at]
  end

  def permitted_associations
    %i[]
  end
end
