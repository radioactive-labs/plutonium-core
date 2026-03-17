class Catalog::MorphDemoPolicy < Catalog::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:record_type, :name, :status, :priority, :scheduled_at, :description, :phone, :category]
  end

  def permitted_attributes_for_read
    [:record_type, :name, :status, :priority, :scheduled_at, :description, :phone, :category]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
