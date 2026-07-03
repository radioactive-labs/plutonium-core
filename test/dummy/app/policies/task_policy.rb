class TaskPolicy < ::ResourcePolicy
  # kanban_move? is the SINGLE authorization for every drag-move (plain moves and
  # enter_interaction columns alike — the interaction has no policy of its own).
  # The from/to columns are supplied via the authorization context, so a specific
  # transition can be gated without a per-column method.
  #
  # deny_kanban_move       — deny ALL moves (board-wide 403 path).
  # deny_enter_column      — deny entering one specific column, exercising the
  #                          from/to context threading (e.g. :lost, :archived).
  cattr_accessor :deny_kanban_move, default: false
  cattr_accessor :deny_enter_column, default: nil

  def kanban_move?
    return false if self.class.deny_kanban_move
    return false if self.class.deny_enter_column && kanban_to&.key == self.class.deny_enter_column
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
    [:title, :status, :position, :lost_reason]
  end

  # Associations

  def permitted_associations
    %i[]
  end
end
