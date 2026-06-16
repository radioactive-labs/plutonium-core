# One-time wizards

A **one-time** wizard runs once — for onboarding, a one-shot setup, a "welcome" flow. It needs a durable completion marker (you can't remember "done forever" in a session), which the DB store provides as a `completed` session row.

## Declaring `one_time`

A one-time wizard is a **keyed** wizard (`concurrency_key`) that **retains** its completed row instead of deleting it. So `one_time` always pairs with a `concurrency_key` — the stable key the retained marker lives at (and the key the gate recomputes).

```ruby
class WelcomeWizard < Plutonium::Wizard::Base
  presents label: "Welcome"

  concurrency_key { current_user }   # the stable row to retain (tenant folded in)
  one_time                            # retain the completed row → never again

  step :greeting do
    attribute :acknowledged, :string
    input :acknowledged
    validates :acknowledged, presence: true
  end

  review label: "Review"

  def execute
    succeed.with_message("Welcome aboard!")
  end
end
```

- **Completion** = the instance row reaching `status: completed`, **retained** at the wizard's `instance_key`.
- **`one_time` requires a `concurrency_key`** — declaring `one_time` without one raises (there's no stable row to retain). A wizard without `one_time` deletes its row on completion (repeatable).
- **`concurrency_key { current_user }`** keys completion per user; **`concurrency_key { anchor }`** keys it per anchored record ("set up *this* workspace once"). The **tenant (`current_scoped_entity`) is folded in automatically**, so in a tenant portal it's per-(user, tenant) for free.
- On completion, the row is kept as the marker but its `data` / `tracked_records` are nulled out (privacy + size).

The completion marker is recorded by the wizard's own finalize, the same `execute` → PRG path as any wizard — no extra code in `execute`.

## Gating a controller — `ensure_wizard_completed`

The `Plutonium::Wizard::Gate` concern installs a `before_action` that redirects users into the wizard until they complete it.

```ruby
module AdminPortal
  class DashboardController < AdminPortal::PlutoniumController
    include Plutonium::Wizard::Gate
    ensure_wizard_completed ::WelcomeWizard
  end
end
```

Flow:

1. An un-completed user hits the gated page → the gate stashes their destination (`session[:return_to]`) and redirects to the wizard's first step.
2. The user completes the wizard → finalize records the durable completion marker.
3. The gate now passes them through; the controller bounces them back to the stashed destination (PRG).
4. A completed user passes straight through, every time.

Extra options (`only:` / `except:`) are forwarded to `before_action`:

```ruby
ensure_wizard_completed ::WelcomeWizard, only: %i[index show]
```

The entry URL is derived from the `register_wizard` route helper (`<name>_wizard_path(step: <first_step>)`). Override `wizard_entry_path` for a custom mount.

## How the gate keys completion

The gate **recomputes the wizard's `instance_key`** from its `concurrency_key`, resolving the key block against the **host controller** — so `current_user`, `current_scoped_entity` (folded automatically), `anchor`, and any custom host method are available — then checks `completed?(instance_key:)`. This digest is computed by the same `Plutonium::Wizard.compute_instance_key` the runner uses, so the gate sees exactly the marker the wizard recorded.

A `concurrency_key { anchor }` wizard therefore keys completion by the anchor with **no extra resolver** — the gate evaluates the key block on the controller, where the anchor context lives. (If your `concurrency_key` references a method the gated controller doesn't expose, you get a clear error rather than a silent mis-key.)

::: warning Only one-time wizards are gateable
`ensure_wizard_completed` raises unless the wizard is `one_time` (a `concurrency_key` **plus** `one_time`) — only a retained marker can be checked. Repeatable wizards have nothing durable to gate on.
:::

## Related

- [DSL reference](/reference/wizard/dsl) — `concurrency_key`, `one_time`, `authorize?`.
- [Storage & config](/reference/wizard/storage-config) — the durable completion row.
- [Registration & launch](/reference/wizard/registration-launch) — mounting the wizard the gate redirects into.
