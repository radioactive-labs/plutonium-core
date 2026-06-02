class Catalog::SpecPolicy < Catalog::ResourcePolicy
  def permitted_attributes_for_create
    [:payload, :rows]
  end
  alias_method :permitted_attributes_for_update, :permitted_attributes_for_create

  def permitted_attributes_for_read
    [:payload, :rows, :created_at]
  end

  def permitted_associations
    %i[]
  end
end
