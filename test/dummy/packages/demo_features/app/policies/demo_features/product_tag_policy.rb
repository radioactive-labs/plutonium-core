class DemoFeatures::ProductTagPolicy < DemoFeatures::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:product, :tag, :position]
  end

  def permitted_attributes_for_read
    [:product, :tag, :position]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
