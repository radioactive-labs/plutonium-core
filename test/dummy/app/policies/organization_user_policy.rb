class OrganizationUserPolicy < ::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:organization, :user, :role]
  end

  def permitted_attributes_for_read
    [:organization, :user, :role]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
