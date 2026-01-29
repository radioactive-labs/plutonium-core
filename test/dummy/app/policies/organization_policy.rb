class OrganizationPolicy < ::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:name]
  end

  def permitted_attributes_for_read
    [:name]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
