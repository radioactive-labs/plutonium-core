class TaskDefinition < ::ResourceDefinition
  kanban do
    per_column 25

    column :todo,
      scope: -> { where(status: "todo") },
      on_drop: ->(r, _ctx) { r.update!(status: "todo") },
      role: :backlog

    column :doing,
      scope: -> { where(status: "doing") },
      on_drop: ->(r, _ctx) { r.update!(status: "doing") },
      wip: 3

    column :done,
      scope: -> { where(status: "done") },
      on_drop: ->(r, _ctx) { r.update!(status: "done") },
      role: :done do
      action :archive_all, interaction: ArchiveTasksInteraction, on: :all, label: "Archive all"
    end
  end
end
