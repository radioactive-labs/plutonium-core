# frozen_string_literal: true

# Drop interaction wired to the TaskDefinition kanban :lost column. Dropping a
# card into :lost opens this interaction's form (asking WHY the task was lost)
# and, on submit, transitions the task to "lost" and records the reason.
#
# Exercises the enter_interaction path: registered as a hidden record action
# (key :lost_enter_interaction), rendered by kanban_move_form, and committed by
# kanban_move. Authorized by kanban_move? — it has no policy method of its own.
class MarkLostInteraction < ::ResourceInteraction
  presents label: "Mark Lost",
    icon: Phlex::TablerIcons::X

  attribute :resource
  attribute :reason, :string

  input :reason

  validates :reason, presence: true

  def execute
    resource.update!(status: "lost", lost_reason: reason)
    succeed(resource).with_message("Marked as lost")
  end
end
