# Kanban Reference

Reference documentation for the Plutonium kanban board feature.

## In this section

| Page | What it covers |
|------|---------------|
| [DSL](/reference/kanban/dsl) | Complete `kanban do…end` DSL — board options, columns, column actions, static vs. dynamic, lazy loading, realtime |
| [Positioning](/reference/kanban/positioning) | `Plutonium::Positioning` concern, `positioned_on`, `position_on` modes, `reposition!`, rebalancing |
| [Authorization](/reference/kanban/authorization) | `kanban_move?` policy predicate, read-only fallback, separating move rights from edit rights |

## Quick start

```ruby
# app/definitions/task_definition.rb
class TaskDefinition < ResourceDefinition
  kanban do
    per_column 25

    column :todo,
      scope:   -> { where(status: "todo") },
      on_drop: ->(r) { r.update!(status: "todo") },
      role: :backlog

    column :doing,
      scope:   -> { where(status: "doing") },
      on_drop: ->(r) { r.update!(status: "doing") },
      wip: 3

    column :done,
      scope:   -> { where(status: "done") },
      on_drop: :mark_done!,
      accepts: [:doing],
      role: :done
  end
end
```

See the [Kanban guide](/guides/kanban) for a full walkthrough including model setup and migrations.
