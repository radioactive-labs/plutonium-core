class TaskDefinition < ::ResourceDefinition
  kanban do
    per_column 25

    # card_fields declares the slot layout for every kanban card on this board.
    # header: :title  — show the task title in the card header.
    # meta: [:status] — show a status badge in the meta row.
    # This overrides the resource definition's grid_fields (which TaskDefinition
    # does not declare, so the default would render header-only).
    card_fields header: :title, meta: [:status]

    column :todo,
      scope: -> { where(status: "todo") },
      on_drop: ->(r) { r.update!(status: "todo") },
      role: :backlog

    column :doing,
      scope: -> { where(status: "doing") },
      on_drop: ->(r) { r.update!(status: "doing") },
      wip: 3

    # :done uses a Symbol on_drop (dispatched as record.mark_done!) and only
    # accepts cards whose current status is "doing" — todo→done drops are
    # rejected.  Uses a Proc accepts: to exercise per-card evaluation in the
    # move handler (GAP 2): the Proc receives the record and returns a boolean.
    column :done,
      scope: -> { where(status: "done") },
      on_drop: :mark_done!,
      accepts: ->(task) { task.status == "doing" },
      role: :done do
      action :archive_all, interaction: ArchiveTasksInteraction, on: :all, label: "Archive all"
    end
  end
end
