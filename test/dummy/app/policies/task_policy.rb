class TaskPolicy < ::ResourcePolicy
  # When set to true in an integration test, kanban_move? returns false so the
  # 403 response path can be exercised without changing production logic.
  cattr_accessor :deny_kanban_move, default: false

  def kanban_move?
    return false if self.class.deny_kanban_move
    super
  end

  # Column action: archive all done tasks.
  # Delegates to update? so any user who can edit tasks can also archive them.
  # Set deny_archive_all = true in integration tests to exercise the hidden-action path.
  cattr_accessor :deny_archive_all, default: false

  def archive_all?
    return false if self.class.deny_archive_all
    update?
  end

  # Drop interaction: mark a task lost (kanban :lost column drop_interaction).
  # Delegates to update? so any user who can edit tasks can mark one lost.
  # Set deny_mark_lost = true in integration tests to exercise the 403 path.
  cattr_accessor :deny_mark_lost, default: false

  def mark_lost?
    return false if self.class.deny_mark_lost
    update?
  end

  # Core actions

  # Set deny_create = true in integration tests to exercise the "+ Add" hidden path.
  cattr_accessor :deny_create, default: false

  def create?
    return false if self.class.deny_create
    super
  end

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
