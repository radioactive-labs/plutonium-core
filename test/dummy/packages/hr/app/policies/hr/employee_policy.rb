class Hr::EmployeePolicy < Hr::ResourcePolicy
  rbac_restricted_attributes :salary

  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:organization, :name, :salary]
  end

  def permitted_attributes_for_read
    [:organization, :name, :salary]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
