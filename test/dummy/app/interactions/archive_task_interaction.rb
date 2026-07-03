# frozen_string_literal: true

# Drop interaction wired to the TaskDefinition kanban :archived column. It
# declares NO user inputs (only the implicit :resource), so the framework marks
# it `immediate` — dropping a card into :archived commits directly (after the
# auto "Archive?" confirmation) instead of opening an empty form modal.
#
# Exercises the immediate drop_interaction path: no kanban_move_form modal, a
# direct kanban_move POST that runs the interaction with no params.
class ArchiveTaskInteraction < ::ResourceInteraction
  presents label: "Archive",
    icon: Phlex::TablerIcons::Archive

  attribute :resource

  def execute
    resource.update!(status: "archived")
    succeed(resource).with_message("Task archived")
  end
end
