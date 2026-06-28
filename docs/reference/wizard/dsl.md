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
| `presents label:, icon:, description:` | The launch button's label + icon (same as interactions), plus an optional `description:` rendered as the wizard's header subheading. |
| `navigation :linear \| :free` | Stepper jump policy. `:linear` (default) — back to any visited step; `:free` — any visible visited step. Forward jumps to unvisited steps are never allowed. |
| `stepper false` | Hide the top rail (the step indicator). On by default. |
| `on_relaunch :new` | Controls a bare relaunch of a **tokened** wizard when the user has pending (in-progress) runs. Default `:prompt` shows a "resume or start new" chooser instead of silently forking; `:new` opts out and always mints a fresh run. No-op for keyed/`anonymous` wizards (they already auto-resume their single run). See [Anchoring & resume](/reference/wizard/anchoring-resume#relaunching-a-tokened-wizard). |
| `anchored with: Model` / `anchored via: :method` | Run against an existing record; read via `anchor`. `with:` resolves from the URL `:id` (resource-mounted); `via:` resolves by calling a controller method (portal-level, context-anchored). See [Anchoring & resume](/reference/wizard/anchoring-resume). |
| `cleanup_after <ttl> \| :never` | Idle TTL before the abandonment sweep reaps a session and rolls back its tracked records. Defaults to `config.wizards.cleanup_after`. `:never` opts out. |
| `concurrency_key { … }` / `concurrency_key :method` | Key a run by the returned value(s) (records → GID, scalars → string, arrays serialized element-wise — structured, **not** flat-joined; the tenant is folded in automatically). The keyed `in_progress` row is the lock — a second launch at the same key resumes, never forks. Omit → unlimited concurrent `wizard_token`-keyed runs — **except** an `anchored` wizard, which defaults to `{ [anchor, current_user] }` (one draft per user per record). See [Anchoring & resume](/reference/wizard/anchoring-resume#the-implied-anchored-key). |
| `one_time` | Retain the completed row at the `concurrency_key` (blocks restart, gate-able). **Requires a `concurrency_key`.** Omit → row deleted on completion (repeatable). See [One-time wizards](/reference/wizard/one-time). |
| `completed do \|wizard\| … end` | Custom body for the "already completed" page a finished **one-time** wizard shows when re-opened (replaces the default confirmation). See [`completed`](#completed) below and [One-time wizards](/reference/wizard/one-time#re-opening-a-completed-wizard). |
| `encrypt_data` | Encrypt the staged `data` column at rest using ActiveRecord's encryption keys (off by default), for flows that stage PII. Requires `active_record.encryption` keys — see [Storage & config](/reference/wizard/storage-config#encryption). |
| `anonymous` | Opt into **guest (unauthenticated) access** — the wizard runs pre-login (auth is required otherwise). The guest's identity is a server-minted run-id in the Rails session; it crosses the auth boundary only at its terminal `execute`. Mount it `public: true` (the default for `anonymous`). **Mutually exclusive with `concurrency_key`/`one_time`** — a guest is already session-keyed and repeatable, so declaring both raises (whichever is declared last). See [Authentication](/reference/wizard/anchoring-resume#authentication). |

```ruby
class CompanyOnboardingWizard < Plutonium::Wizard::Base
  presents label: "Onboard a company", icon: Phlex::TablerIcons::BuildingSkyscraper
  navigation :linear
  # ... steps ...
end
```

## `step`

```ruby
step(key, label: nil, description: nil, condition: nil, using: nil, **using_opts, &block)
```

A `step` is one screen. The block declares its fields with the existing field DSL (`attribute`/`input`/`validates`/`structured_input`/`form_layout`) and may attach the per-step hooks `on_submit`/`on_rollback`.

```ruby
step :company, label: "Company details", condition: -> { data.plan.kind == "business" } do
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
| `label:` | The step's display label (stepper + heading). Defaults to `key.to_s.humanize`. |
| `description:` | Optional sub-label rendered under the step heading. |
| `condition:` | Lambda over `data` (and `anchor`) gating inclusion. Subtractive branching. Must be nil-safe. |
| `using:` | Import a field surface from a **model**. See below. |

The block is optional only when `using:` supplies everything.

### Fields inside a step

A step's block is the same field DSL used on definitions and interactions:

- `attribute :name, :type` — declares a typed attribute (feeds the `data` snapshot).
- `input :name, as:, ...` — how the field renders.
- `validates :name, ...` — ActiveModel validations, run on Next. These also drive the form's field affordances exactly like a resource form: a `presence` validation renders the required marker (`*`), and `length`/`numericality`/`format`/`inclusion` feed `maxlength`/`min`/`max`/`pattern`/auto-choices. Validations imported via `using:` surface these too.
- `structured_input :name, repeat: N do |f| ... end` — a repeatable/structured group → `data.<step>.name` is an array of typed sub-objects. The sub-fields can come from the block (above), or from a model via `using:` / `fields:` (same selectors as a step's `using:`) instead of a block.
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

### Attachment fields

A file field is a **`:string`** attribute (it holds the upload **token**, not the bytes) plus a file input (`as: :file`, `:uppy`, or `:attachment`):

```ruby
step :photo, label: "Photo" do
  attribute :photo, :string
  input :photo, as: :file                    # server-side staged (default)
  # input :photo, as: :uppy, direct_upload: true, endpoint: "/upload"  # direct upload
end
```

`data` is JSON staged across requests, so a file can't ride along — only its backend **token** (an ActiveStorage signed_id, or active_shrine/Shrine cached-file data). `execute` assigns the token to the model's attachment natively (`model.photo.attach(data.photo.photo)` for AS, `model.update!(photo: data.photo.photo)` for active_shrine). The review summary and the input preview (on Back/resume) resolve the token to a displayable attachment automatically.

| | Declare | Behaviour |
|---|---|---|
| **Server-side** (default) | `as: :file` | file submitted with the step; the wizard uploads it to the backend cache while staging. AS *and* active_shrine. |
| **Direct upload** | `as: :uppy, direct_upload: true, endpoint:` | browser uploads to the endpoint, posts a token (async UI). |
| **Backend** (server-side) | `backend: :active_storage` / `:shrine` | defaults to `config.wizards.attachment_backend` (auto-detects active_shrine, else AS). **Must match the model** `execute` assigns to. |
| **Uploader** (Shrine only) | `uploader: PhotoUploader` | cache the file through a specific Shrine uploader (its cache-stage plugins — mime/dimension extraction, `generate_location`, processing — run instead of base `Shrine`'s). The minted token stays uploader-agnostic, so display + promotion are unaffected. Accepts a class or a class-name string; raises for the AS backend. Server-side staging only (direct upload configures the uploader at its endpoint). Its **validations are enforced on the step** — see the note below. |
| **Multiple** | array attribute + `multiple: true` | staged value is an array of tokens. |

::: tip Uploader validations are enforced on the step
A Shrine file field is validated **on its step** against the field's **effective uploader** — its `uploader:` if given, else base `Shrine` (whichever carries the `Attacher.validate` rules). A file that violates them is rejected right there (a field error + re-render), exactly like a `validates` — *not* deferred to `execute`. Mechanically: `Uploader.upload` caches the file (running no validations), then the step's validation pass runs the attacher's validations against the staged token. ActiveStorage fields are unaffected, and a base `Shrine` with no rules is a no-op.
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
  charge = PaymentApi.authorize!(anchor, data.billing.card_token)
  fail!("Card was declined") unless charge.ok?
  persist Billing.create!(company: anchor, token: data.billing.card_token, charge_id: charge.id)
end
```

The wizard never advances past a failed `on_submit`. Earlier committed steps are untouched (undo them via Cancel → cleanup).

### `on_rollback`

Rollback happens on Cancel, abandonment-sweep, **or when this step becomes branch-hidden** (a later answer flips its `condition:` false, so save-as-you-go records it created would otherwise be orphaned). On any of these, the engine **always** destroys every `persist`'d record in reverse step order via `destroy!` (which respects a model's own soft-delete/paranoia override). When a step is pruned this way its `data` / `persisted` / `visited` state is also cleared, so re-entering that branch re-runs `on_submit` from scratch.

`on_rollback` is an **optional, ADDITIONAL** compensating block for side effects the engine can't see: refunding a charge, calling an external API, deleting something `persist` didn't track. It reads `persisted[...]` and runs **before** the engine's destroy (records still alive), **in addition to** it, never instead of it. Don't destroy the `persist`'d record yourself in the block; the engine does that.

```ruby
# The engine destroys persisted[:billing] for you; this just refunds the charge.
on_rollback { PaymentApi.refund!(persisted[:billing].charge_id) }
```

Supply an `on_rollback` when abandonment must do more than drop the record(s) (refund a charge, call an external API), or when `on_submit` registered no record at all (side-effect-only steps, whose `on_rollback` still runs). To *keep* a partial record rather than destroy it, make the model itself soft-delete (so its `destroy!` detaches) or use `cleanup_after :never`.

## `review`

```ruby
review(label: "Review", description: nil, condition: nil, summary: true, header: true, &block)
```

The built-in **terminal** step. Must be last. It lists outstanding (invalid/unvisited) steps as jump links and gates Finish until all visible steps are valid. It declares no fields of its own.

What it renders depends on completion state and the `summary:` / block options:

| State | Body |
|---|---|
| **Incomplete** (a visible step is invalid/unvisited) | The outstanding "fix this" links **+** the auto-summary of what's entered so far (the review-and-fix view). |
| **Complete**, `summary: true` (default) | The auto-summary of every visible step; the custom block, if any, renders **below** it. |
| **Complete**, `summary: false`, with a block | The custom block **replaces** the summary (author owns the body). |
| **Complete**, `summary: false`, no block | A built-in "ready to complete" confirmation panel. |

| Option | Meaning |
|---|---|
| `label:` | The review step's label (default `"Review"`). |
| `description:` | Optional sub-label under the review heading. |
| `summary:` | Show the auto-summary of completed steps (default `true`). When `false`, the complete-state body is your block — or the built-in "ready to complete" panel if there's no block. The summary always renders in the incomplete state. |
| `header:` | Show the step-header section (the label plus the "check everything over" prompt, which only appears when the summary is shown) above the body (default `true`). `false` drops it for a chromeless finish. |

```ruby
review label: "Review & submit"                       # auto-summary + gated finish

review label: "Review & submit" do |wizard|           # custom content BELOW the summary
  "By submitting you agree to the #{wizard.data.plan.plan} plan terms."
end

review summary: false, header: false                  # fully chromeless → "ready to complete" panel
```

::: tip
`stepper false` (a wizard-level macro) + `review summary: false, header: false` + no block gives a fully chromeless flow (no rail, no header, no summary), ending on the built-in "ready to complete" panel.
:::

### The custom block's render context

The block runs **in the Phlex view context** (`self` is the rendering component), not the controller — that's what lets it emit markup. So you can:

- **return a String** (the simplest case) — it renders as the block's text;
- **emit Phlex** directly — `div`, `span`, `plain`, `render SomeComponent.new(...)`;
- reach **view / route helpers** via `helpers.*` (e.g. `helpers.link_to`, `helpers.current_user`, a path helper).

The block is **yielded the wizard**, so `wizard.data`, `wizard.anchor`, `wizard.persisted`, and `wizard.current_user` are all in hand.

```ruby
review label: "Review & submit" do |wizard|
  div(class: "text-sm") do
    plain "Billing to "
    strong { wizard.data.company.name }
    plain " — "
    plain helpers.link_to("see our terms", helpers.terms_path)
  end
end
```

Don't mix styles in one block: Phlex emits a returned String *in addition to* anything you wrote with `div`/`render`, so returning a String after emitting markup double-renders it. Pick one.

## `completed`

```ruby
completed do |wizard|
  # …Phlex body…
end
```

A custom body for the **"already completed" page** — what a finished [one-time wizard](/reference/wizard/one-time#re-opening-a-completed-wizard) shows when a user re-opens it. On completion a one-time wizard retains its row but clears the `data`, so there's nothing to review; re-entry renders this standalone page instead of re-running the flow. Only meaningful for one-time wizards (repeatable ones leave no completed row, so re-launching just starts fresh).

Without `completed`, a built-in confirmation renders (a success badge, the wizard's label, a short message, and a Continue button out). The block **replaces that body entirely** — you supply your own content (and your own way out):

```ruby
class WelcomeWizard < Plutonium::Wizard::Base
  concurrency_key { current_user }
  one_time
  # …steps…

  completed do |wizard|
    h1 { "You're all set up!" }
    a(href: "/dashboard") { "Go to your dashboard" }
  end
end
```

The block runs in the **same Phlex view context** as the [review block](#the-custom-block-s-render-context) (`self` is the component; reach helpers via `helpers.*`) and is yielded the `wizard`. The same don't-mix-styles caveat applies.

## `execute`

The at-end commit hook, run once after the last visible step, in one transaction.

```ruby
def execute
  company = Company.create!(name: data.company.name, subdomain: data.company.subdomain)
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
| `data` | Typed, dot-accessible snapshot of everything entered so far, **step-keyed** — read a field through its owning step: `data.<step>.<field>`. Read-only; not-yet-collected fields read as `nil` or their `default:`. Each step has its own sub-object, so two steps may declare the same field name without colliding. |
| `data.<step>.<field>` | The cast value (real Boolean/Integer/Date, not raw string). `data.<step>.<structured>` → array of typed sub-objects. An unknown step key reads as `nil`. |
| `anchor` | The record the wizard was launched against. Raises `NotAnchoredError` if the wizard isn't `anchored`. |
| `persisted[:step_key]` | Record(s) a per-step `on_submit` registered via `persist`. Lazily rehydrated on first access (located from stored GlobalIDs the first time you read the key, memoized thereafter). |

## Outcome helpers

| Helper | Use |
|---|---|
| `succeed(value = nil)` | Success outcome (alias `success`). Chain `.with_message(...)`, `.with_redirect_response(...)`. |
| `failed(errors = nil, attribute = :base)` | Failure outcome. Accepts a string, an array, a hash (`{field => msg}`), or an errors object. |
| `fail!("message")` / `fail!(:field, "message")` | Raise a `StepError` from `on_submit`/`execute` (sugar over `raise`). |

## Errors

| Error | Raised when |
|---|---|
| `Plutonium::Wizard::NotAnchoredError` | `anchor` called on a non-anchored wizard (also raised when a `via:` anchor resolves to `nil` or the wrong type). |
| `Plutonium::Wizard::StepError` | Raised by `fail!` (or directly) for a custom, non-AR step failure → maps to a form error. |
| `Plutonium::Wizard::UnknownWizardError` | A mount's `wizard_class` doesn't resolve to a loaded `Plutonium::Wizard::Base` subclass — a misconfigured mount or a tampered route param. |

## Related

- [Anchoring & resume](/reference/wizard/anchoring-resume)
- [Storage & config](/reference/wizard/storage-config)
- [Registration & launch](/reference/wizard/registration-launch)
- [One-time wizards](/reference/wizard/one-time)
