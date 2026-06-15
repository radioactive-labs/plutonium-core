# One-time wizards

A **one-time** wizard runs once — for onboarding, a one-shot setup, a "welcome" flow. It needs a durable completion marker (you can't remember "done forever" in a session), which the DB store provides as a `completed` session row.

## Declaring `one_time`

```ruby
class WelcomeWizard < Plutonium::Wizard::Base
  presents label: "Welcome"
  one_time once_per: :user        # :user (default) | :anchor

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

- **Completion** = the instance row reaching `status: completed`. `one_time` implies durable completion automatically.
- **`once_per: :user`** (default) keys completion by the current user.
- **`once_per: :anchor`** keys completion by the anchor's GlobalID ("set up *this* workspace once").
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

## `once_per: :anchor`

For an anchor-keyed one-time wizard, the gate can't generically know *which* record it's about, so you must supply it by overriding `wizard_gate_anchor` in the gated controller:

```ruby
module AdminPortal
  class WorkspaceController < AdminPortal::PlutoniumController
    include Plutonium::Wizard::Gate
    ensure_wizard_completed ::WorkspaceSetupWizard

    private

    def wizard_gate_anchor(_wizard_class)
      current_scoped_entity          # e.g. the current tenant / workspace
    end
  end
end
```

::: warning As-built: `once_per: :anchor` needs a resolver
The default `wizard_gate_anchor` raises `NotImplementedError` rather than silently mis-keying the completion check. `once_per: :user` is the primary, fully-supported case; `:anchor` gating requires this host-provided resolver.
:::

## Related

- [DSL reference](/reference/wizard/dsl) — `one_time`, `authorize?`.
- [Storage & config](/reference/wizard/storage-config) — the durable completion row.
- [Registration & launch](/reference/wizard/registration-launch) — mounting the wizard the gate redirects into.
