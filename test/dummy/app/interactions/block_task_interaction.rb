# frozen_string_literal: true

# Drop interaction wired to the TaskDefinition kanban :blocked column, which ALSO
# declares an on_drop. Used by the drop-interaction coverage tests to prove that
# a column can run BOTH an on_drop membership write and a drop_interaction, and
# that they run in order (on_drop first, then the interaction).
#
# The :blocked on_drop sets status="blocked" and stamps lost_reason with a
# sentinel; this interaction then overwrites lost_reason with the user-supplied
# reason. The sentinel being gone from lost_reason proves the interaction ran
# AFTER on_drop.
class BlockTaskInteraction < ::ResourceInteraction
  presents label: "Block Task",
    icon: Phlex::TablerIcons::Ban

  attribute :resource
  attribute :reason, :string

  input :reason

  validates :reason, presence: true

  def execute
    resource.update!(status: "blocked", lost_reason: reason)
    succeed(resource).with_message("Task blocked")
  end
end
