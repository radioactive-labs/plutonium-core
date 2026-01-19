class DemoFeatures::ReviewPolicy < DemoFeatures::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:product, :user, :title, :body, :rating, :verified, :approved_at]
  end

  def permitted_attributes_for_read
    [:product, :user, :title, :body, :rating, :verified, :approved_at]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
