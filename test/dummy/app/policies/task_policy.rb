class TaskPolicy < ::ResourcePolicy
  # When set to true in an integration test, kanban_move? returns false so the
  # 403 response path can be exercised without changing production logic.
  cattr_accessor :deny_kanban_move, default: false

  def kanban_move?
    return false if self.class.deny_kanban_move
    super
  end

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
