class TaskDefinition < ::ResourceDefinition
  kanban do
    per_column 25

    column :todo,
      scope: -> { where(status: "todo") },
      on_drop: ->(r) { r.update!(status: "todo") },
      role: :backlog

    column :doing,
      scope: -> { where(status: "doing") },
      on_drop: ->(r) { r.update!(status: "doing") },
      wip: 3

    # :done uses a Symbol on_drop (dispatched as record.mark_done!) and only
    # accepts cards dragged from :doing — direct todo→done drops are rejected.
    column :done,
      scope: -> { where(status: "done") },
      on_drop: :mark_done!,
      accepts: [:doing],
      role: :done do
      action :archive_all, interaction: ArchiveTasksInteraction, on: :all, label: "Archive all"
    end
  end
end
