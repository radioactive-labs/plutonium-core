class TaskDefinition < ::ResourceDefinition
  search do |scope, query|
    scope.where("title LIKE ?", "%#{query}%")
  end

  kanban do
    per_column 25

    # Open a card's show page as a full-page navigation rather than the default
    # modal. KitchenSinkDefinition exercises the default (:modal) path.
    show_in :page

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

    # :lost declares a drop_interaction — dropping a card here opens
    # MarkLostInteraction's form (asking for a reason) instead of moving the
    # card immediately. Exercises the kanban_move_form modal + kanban_move
    # atomic-commit path.
    column :lost,
      scope: -> { where(status: "lost") },
      drop_interaction: MarkLostInteraction
  end
end
