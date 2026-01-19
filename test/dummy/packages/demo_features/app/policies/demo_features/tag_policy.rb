class DemoFeatures::TagPolicy < DemoFeatures::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:name, :color]
  end

  def permitted_attributes_for_read
    [:name, :color]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
