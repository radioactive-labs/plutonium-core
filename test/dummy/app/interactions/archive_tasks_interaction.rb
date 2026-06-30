# frozen_string_literal: true

# Trivial bulk interaction used by the kanban "done" column action.
# Archives all tasks passed via the :resources collection.
class ArchiveTasksInteraction < ::ResourceInteraction
  presents label: "Archive all",
    icon: Phlex::TablerIcons::Archive

  attribute :resources

  def execute
    count = resources.count
    resources.update_all(status: "archived")
    succeed(resources).with_message("Archived #{count} tasks")
  end
end
