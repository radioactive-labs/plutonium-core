class AdminPolicy < ::ResourcePolicy
  # Core actions

  def create?
    true
  end

  def read?
    true
  end

  # Core attributes

  def permitted_attributes_for_create
    [:email, :status]
  end

  def permitted_attributes_for_read
    [:email, :status]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
