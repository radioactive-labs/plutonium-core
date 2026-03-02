class ProfilePolicy < ::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:user]
  end

  def permitted_attributes_for_read
    [:user]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
