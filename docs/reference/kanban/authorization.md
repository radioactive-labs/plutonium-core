# Kanban Authorization

## `kanban_move?` policy predicate

Every drag-and-drop move is authorized through the `kanban_move?` method on the resource's policy. The default implementation delegates to `update?`:

```ruby
# Plutonium::Resource::Policy — built-in default
def kanban_move?
  update?
end
```

Override it in your policy to give finer control:

```ruby
class TaskPolicy < ResourcePolicy
  # Allow all authenticated members to drag cards,
  # but require :admin to open the edit form.
  def kanban_move?
    user.member?
  end

  def update?
    user.admin?
  end
end
```

## Read-only board

When `kanban_move?` returns `false` for the current user, the board is rendered read-only. Cards are displayed but dragging is disabled — no drag handles appear and the Stimulus controller does not register drop zones.

## Authorization flow on a move

When a card is dropped, the server:

1. Finds the record within the current authorized scope (the same policy `relation_scope` used by the index action).
2. Calls `authorize_current!(record, to: :kanban_move?)`. A `false` result halts the action with HTTP 403.
3. Validates the drop against the destination column's `accepts:` policy and `locked:` flag. A rejected drop responds with HTTP 422 and re-renders the source column (the Stimulus controller snaps the card back).
4. Enforces the destination column's `wip:` limit (cross-column moves only). Exceeding the WIP cap also responds 422.
5. Calls `on_drop` and repositions the record inside a transaction.

## No permitted attributes for moves

Kanban moves do **not** pass through `permitted_attributes_for_update` / `permitted_attributes_for_kanban_move`. The `on_drop` callback is author code that runs with full model access — it is the responsibility of the `on_drop` implementation to assign only the attributes appropriate for a column transition. This is intentional: the callback is trusted Ruby, not user-supplied form data.

## Column-level drop policies

The `accepts:`, `locked:`, and `wip:` column options enforce additional constraints beyond `kanban_move?`:

| Constraint | What it checks | On failure |
|------------|---------------|------------|
| `accepts:` | Source column key is allowed | 422 + card snap-back |
| `locked:` | Source column is not locked | 422 + card snap-back |
| `wip:` | Cross-column count within limit | 422 + card snap-back |

These checks run server-side after `kanban_move?` succeeds. The client-side Stimulus controller reads `data-kanban-accepts` and `data-kanban-locked` attributes to provide visual drop hints, but the server remains the authority.

## Quick-add authorization

The `+ Add` button (shown when `add: true` is set on a column) is only rendered when the current policy's `create?` returns `true`. The new form opened by quick-add is the standard resource new form and goes through the normal creation authorization flow.
