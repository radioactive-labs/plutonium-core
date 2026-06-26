class TaskPolicy < ::ResourcePolicy
  # Core actions

  # def create?
  #   true
  # end

  # def read?
  #   true
  # end

  # Core attributes

  def permitted_attributes_for_create
    [:title, :status, :position]
  end

  def permitted_attributes_for_read
    [:title, :status, :position]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
