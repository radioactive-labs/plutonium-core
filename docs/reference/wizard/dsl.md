# Wizard DSL

A wizard is a Ruby class — `class X < Plutonium::Wizard::Base`. It declares ordered `step`s, an optional terminal `review` step, wizard-level options, and an `execute` commit hook. This page is the full reference for the author-facing DSL.

For task-oriented walkthroughs, start with the [Wizards guide](/guides/wizards).

## 🚨 Critical

- **Use bang methods** (`create!`/`update!`/`save!`) in `on_submit` and `execute`. Failure is signalled by a raised exception — a non-bang `false` return advances the wizard and silently loses data.
- **`condition:` lambdas must be nil-safe.** They run against the typed `data` snapshot at every transition, including before their deciding step is filled (`nil`).
- **`review` must be the last step.** Declaring a step after `review` raises at load time.
- **`using:` targets a model only** — not an interaction, not a bare definition.
- **`execute` returns an Outcome** — `succeed(...)` / `failed(...)`, or raise to fail.

## Wizard-level macros

| Macro | Meaning |
|---|---|
| `presents label:, icon:` | The launch button's label + icon (same as interactions). |
| `navigation :linear \| :free` | Stepper jump policy. `:linear` (default) — back to any visited step; `:free` — any visible visited step. Forward jumps to unvisited steps are never allowed. |
| `anchored with: Model` | Run against an existing record; read via `anchor`. See [Anchoring & resume](/reference/wizard/anchoring-resume). |
| `cleanup_after <ttl> \| :never` | Idle TTL before the abandonment sweep reaps a session and rolls back its tracked records. Defaults to `config.wizards.cleanup_after`. `:never` opts out. |
| `one_time once_per: :user \| :anchor` | Run once; record a durable completion marker. See [One-time wizards](/reference/wizard/one-time). |
| `encrypt_data` | Apply Rails `encrypts` to the `data`/`tracked_records` columns (off by default), for flows that stage PII. |

```ruby
class CompanyOnboardingWizard < Plutonium::Wizard::Base
  presents label: "Onboard a company", icon: Phlex::TablerIcons::BuildingSkyscraper
  navigation :linear
  # ... steps ...
end
```

## `step`

```ruby
step(key, label: nil, condition: nil, using: nil, **using_opts, &block)
```

A `step` is one screen. The block declares its fields with the existing field DSL (`attribute`/`input`/`validates`/`structured_input`/`form_layout`) and may attach the per-step hooks `on_submit`/`on_rollback`.

```ruby
step :company, label: "Company details", condition: -> { data.kind == "business" } do
  attribute :name, :string
  attribute :subdomain, :string
  input :name
  input :subdomain
  validates :name, :subdomain, presence: true

  form_layout do
    section :identity, :name, :subdomain, label: "Identity", columns: 2
  end
end
```

| Option | Meaning |
|---|---|
| `label:` | The step's display label (stepper + heading). |
| `condition:` | Lambda over `data` (and `anchor`) gating inclusion. Subtractive branching. Must be nil-safe. |
| `using:` | Import a field surface from a **model**. See below. |

The block is optional only when `using:` supplies everything.

### Fields inside a step

A step's block is the same field DSL used on definitions and interactions:

- `attribute :name, :type` — declares a typed attribute (feeds the `data` snapshot).
- `input :name, as:, ...` — how the field renders.
- `validates :name, ...` — ActiveModel validations, run on Next.
- `structured_input :name, repeat: N do |f| ... end` — a repeatable/structured group → `data.name` is an array of typed sub-objects.
- `form_layout do ... end` — section the step's fields (`section`, `columns:`, `collapsible:`, etc.), scoped to this step.

See [plutonium-resource › Definition](/reference/resource/definition) for the full field/input/layout vocabulary.

### `using:` a model

`using:` imports field declarations from an ActiveRecord model so a step needn't re-declare them. It is a **step option**, not a block method (avoids Ruby's `Module#using` refinements clash), and it targets a **model only**.

```ruby
step :branding, label: "Branding", using: Company, fields: %i[logo brand_color]

step :details, label: "Details", using: Company, only: %i[tagline] do
  attribute :referral_code, :string   # plus a wizard-local field
  input :referral_code
end
```

What gets imported:

| Source | Imported |
|---|---|
| `Model.attribute_names` / `attribute_types` | The field universe + cast types. |
| `<Model>Definition` (auto-resolved) | Input styling (`as:`, options, labels). Best-effort — no definition is fine. |
| Transient `Model.new(slice).valid?` | Validations, keeping errors on imported fields + `:base`. |
| `<Model>Definition#form_layout` | Section layout, filtered to imported fields. |

| Selector / flag | Effect |
|---|---|
| `fields:` (alias `only:`) | Import only these attributes. |
| `except:` | Import everything except these. |
| `validate: false` | Skip validation reuse (write your own inline `validates`). |
| `layout: false` | Skip inherited `form_layout` (default single grid). |
| `validation_context:` | Run `valid?(context)` for context-scoped model validations. |

**Declaration reuse only** — `using:` never pulls in the model's persistence or callbacks. Data stages into `data`; your `execute`/`on_submit` does the writes.

::: tip Why a model, not a definition
A `Plutonium::Resource::Definition` carries no link to its model — the controller binds them at request time. The only reliable direction is **model → definition**, so the model is the reuse target, and `<Model>Definition` is auto-resolved from it for styling.
:::

## Per-step hooks

`execute` is the default commit point (atomic, at the end). Per-step `on_submit` is opt-in save-as-you-go — use it only when a real record must exist mid-flow.

### `on_submit`

Runs in its own transaction when the step completes (after its fields validate). Inside it:

- `persist record` (or a list) — register record(s) the engine tracks for resume + cleanup → `persisted[:step_key]`.
- `fail!("message")` — abort with a base (form-level) error.
- `fail!(:field, "message")` — abort with a field-level error.

```ruby
on_submit do
  charge = PaymentApi.authorize!(anchor, data.card_token)
  fail!("Card was declined") unless charge.ok?
  persist Billing.create!(company: anchor, token: data.card_token, charge_id: charge.id)
end
```

The wizard never advances past a failed `on_submit`. Earlier committed steps are untouched (undo them via Cancel → cleanup).

### `on_rollback`

The compensating block run on Cancel or abandonment-sweep. Reads `persisted[...]`. Omitted, the engine destroys the tracked record(s) in reverse step order.

```ruby
on_rollback { persisted[:billing].destroy! }
```

Supply a custom `on_rollback` when undo needs more than a destroy (refund a charge, detach instead of delete), or when `on_submit` registered no record (side-effect-only steps).

## `review`

```ruby
review(label: "Review", condition: nil, &block)
```

The built-in **terminal** step. Must be last. It auto-summarizes every visible step's data, lists outstanding (invalid/unvisited) steps as jump links, and gates Finish until all visible steps are valid.

```ruby
review label: "Review & submit"

# Custom content after the auto-summary — the block receives the wizard:
review label: "Review & submit" do |wizard|
  "By submitting you agree to the #{wizard.data.plan} plan terms."
end
```

A `review` step declares no fields of its own.

## `execute`

The at-end commit hook, run once after the last visible step, in one transaction.

```ruby
def execute
  company = Company.create!(name: data.name, subdomain: data.subdomain)
  succeed(company).with_message("You're all set!")
end
```

- Returns a `succeed(value)` / `failed(errors)` Outcome (the same Outcome interactions use — `.with_message`, `.with_redirect_response`, etc. all work).
- **Use bang methods** so a failure raises. The engine catches `ActiveRecord::RecordInvalid` (→ field errors) and `Plutonium::Wizard::StepError` (→ base error via `fail!`); any other error re-raises as a 500.
- On success the wizard marks the session completed, clears `data`/`persisted`, and redirects (PRG) so a back-button replay can't re-run `execute`.

## Entry authorization — `authorize?`

A portal-level (standalone) wizard has no resource policy, so gate entry by defining an `authorize?` instance method. The controller checks it before each request; a falsy return → `ActionPolicy::Unauthorized` (403).

```ruby
def authorize?
  current_user.present? && !current_user.onboarded?
end
```

::: warning As-built: `authorize?` is an instance method
Define `def authorize?` on the wizard. (Resource-attached wizards instead use their action's policy predicate — see [Registration & launch](/reference/wizard/registration-launch).)
:::

## Accessors

Available inside steps, `condition:`, `on_submit`, `on_rollback`, and `execute`:

| Accessor | Returns |
|---|---|
| `data` | Typed, dot-accessible snapshot of everything entered so far (union of all steps' attributes). Read-only; not-yet-collected fields read as `nil` or their `default:`. |
| `data.<field>` | The cast value (real Boolean/Integer/Date, not raw string). `data.<structured>` → array of typed sub-objects. |
| `anchor` | The record the wizard was launched against. Raises `NotAnchoredError` if the wizard isn't `anchored`. |
| `persisted[:step_key]` | Record(s) a per-step `on_submit` registered via `persist`. Rehydrated on resume. |

## Outcome helpers

| Helper | Use |
|---|---|
| `succeed(value = nil)` | Success outcome (alias `success`). Chain `.with_message(...)`, `.with_redirect_response(...)`. |
| `failed(errors = nil, attribute = :base)` | Failure outcome. Accepts a string, an array, a hash (`{field => msg}`), or an errors object. |
| `fail!("message")` / `fail!(:field, "message")` | Raise a `StepError` from `on_submit`/`execute` (sugar over `raise`). |

## Errors

| Error | Raised when |
|---|---|
| `Plutonium::Wizard::NotAnchoredError` | `anchor` called on a non-anchored wizard. |
| `Plutonium::Wizard::StepError` | Raised by `fail!` (or directly) for a custom, non-AR step failure → maps to a form error. |

## Related

- [Anchoring & resume](/reference/wizard/anchoring-resume)
- [Storage & config](/reference/wizard/storage-config)
- [Registration & launch](/reference/wizard/registration-launch)
- [One-time wizards](/reference/wizard/one-time)
