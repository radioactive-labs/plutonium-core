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

    # :todo declares an on_exit — the SOURCE-side counterpart to on_enter. It
    # stamps a sentinel on lost_reason when a card LEAVES :todo (cross-column
    # only), exercising the exit hook: fires before on_enter, participates in the
    # atomic transaction, and is skipped on same-column reorders.
    column :todo,
      scope: -> { where(status: "todo") },
      on_enter: ->(r) { r.update!(status: "todo") },
      on_exit: ->(r) { r.lost_reason = "EXITED_TODO" },
      role: :backlog

    column :doing,
      scope: -> { where(status: "doing") },
      on_enter: ->(r) { r.update!(status: "doing") },
      wip: 3

    # :done uses a Symbol on_enter (dispatched as record.mark_done!) and only
    # accepts cards whose current status is "doing" — todo→done drops are
    # rejected.  Uses a Proc accepts: to exercise per-card evaluation in the
    # move handler (GAP 2): the Proc receives the record and returns a boolean.
    column :done,
      scope: -> { where(status: "done") },
      on_enter: :mark_done!,
      accepts: ->(task) { task.status == "doing" },
      role: :done do
      action :archive_all, interaction: ArchiveTasksInteraction, on: :all, label: "Archive all"
    end

    # :lost declares a enter_interaction — dropping a card here opens
    # MarkLostInteraction's form (asking for a reason) instead of moving the
    # card immediately. Exercises the kanban_move_form modal + kanban_move
    # atomic-commit path.
    column :lost,
      scope: -> { where(status: "lost") },
      enter_interaction: MarkLostInteraction

    # :blocked declares BOTH an on_enter AND a enter_interaction. The on_enter sets
    # status="blocked" (membership) and stamps lost_reason with a sentinel; the
    # BlockTaskInteraction then overwrites lost_reason with the user's reason.
    # Exercises the ordering guarantee (on_enter runs, THEN the interaction) — see
    # KanbanDropInteractionTest's on_enter+interaction coverage test.
    column :blocked,
      scope: -> { where(status: "blocked") },
      on_enter: ->(r) {
        r.status = "blocked"
        r.lost_reason = "SET_BY_ON_DROP"
      },
      enter_interaction: BlockTaskInteraction

    # :archived declares an IMMEDIATE enter_interaction — ArchiveTaskInteraction
    # takes no user inputs, so the framework marks it immediate. Dropping a card
    # here commits directly (with an auto "Archive?" confirmation) instead of
    # opening an empty form modal — the immediate enter_interaction path.
    column :archived,
      scope: -> { where(status: "archived") },
      enter_interaction: ArchiveTaskInteraction
  end
end
