# Wizard DSL — Design

**Date:** 2026-06-15
**Status:** Pending final user sign-off (external technical review incorporated — all blocking + should-address items resolved)
**Scope:** A declarative, multi-step **wizard** system for Plutonium, living in plutonium-core under a new `Plutonium::Wizard` namespace.

---

## 1. Goal & Motivation

Plutonium has interactions (single-shot business logic with a form), actions, and form sectioning, but no first-class way to build **multi-step flows**. We want a declarative DSL for wizards that covers, in one model, the three shapes that came up:

1. **Multi-model create** — one flow that creates/updates several related records across steps (e.g. Company → Plan → Billing → Team).
2. **Single complex object** — one logical record built up over several screens because it has too many fields/decisions for one form.
3. **Branching process** — answers in early steps change which later steps appear.

The wizard system orchestrates **existing** Plutonium infrastructure (the field/input DSL, form rendering, form layout, actions, policies) rather than inventing a parallel stack. It does **not** route steps through interactions — interactions own their own endpoint, params, redirects, and outcome→response handling, and wiring that as a sub-step fights the abstraction.

### Design validation (cross-framework research)

Three independent research sweeps (Rails ecosystem; Django/Symfony/Spring/.NET/Laravel; XState/React/LiveView/declarative schema builders) converged on the same conclusions this design reaches independently:

- **Ordered-steps-with-conditions is the right spine**, *not* a full state machine. SurveyJS, JSONForms, Django `formtools`, Symfony's native flow (7.4), Spatie Livewire wizard, and Phoenix LiveView all default to "ordered steps + per-step condition predicate." Statecharts / Spring Web Flow earn their transition-graph complexity only with loops, joins, or arbitrary jumps — which typical app wizards do not need.
- **A single transactional finalization hook receiving merged data** is the consensus commit pattern (Django `done()`, Spring end-state, Spatie last-step). Maps to our `execute` returning an `Outcome`.
- **Pluggable storage with a durable option** is universal (Django Session vs Cookie; Symfony Session vs DB marking; LiveView in-memory vs draft row).

Refinements folded in from the research:

- **Back never validates and never discards data** — navigation, not submission.
- **Prevent double-commit** — clear state + redirect (PRG) on success so a back-button replay cannot re-run `execute`.
- **Branching is subtractive with a guaranteed path** — divergent paths are mutually-exclusive `condition:` lambdas; the engine must never reach "no valid next step."

Key references: `github.com/zombocom/wicked`, `evilmartians.com/chronicles/hotwire-rails-summit-interactive-multi-step-forms-peak-ux`, `django-formtools.readthedocs.io/en/latest/wizard.html`, `symfony.com/doc/current/workflow.html`, `docs.spring.io/spring-webflow`, `bernheisel.com/blog/liveview-multi-step-form`, `stately.ai/blog/2023-10-02-persisting-state`, `docs.aws.amazon.com/step-functions/latest/dg/state-choice.html`.

### Prior art: the keystone registration wizard

A real wizard already exists in the `keystone` app (founder registration). It is a **different construct**: a read-only presenter that **hosts existing Plutonium resource CRUD forms** in turbo-frames (each step points at `{resource:, action:}`), persists through those resources' own controllers as the user goes, keeps **no wizard state table** (state *is* the domain records), and derives progress from **domain completeness checkers** rather than per-step form validation. It's an *orchestration/hosting* wizard over existing resources.

This design deliberately stays a **self-contained data-capture** wizard (the wizard owns its fields and stages state) rather than adopting the hosting model — but borrows two of keystone's ideas: a built-in **review step** (§2.5) and **field reuse** so steps can import declarations *and validations* from a definition/interaction instead of re-declaring them (§2.4). The hosting/orchestration style is **not pursued** (the team decided against building it).

---

## 2. Author-facing DSL

A wizard is a Ruby class, authored like an interaction (no generator — see §11).

The common case writes nothing until the end — steps only collect `data` and branch, and a single `execute` does all writes atomically:

```ruby
class CompanyOnboardingWizard < Plutonium::Wizard::Base
  presents label: "Onboard a company", icon: Phlex::TablerIcons::Building

  navigation :linear      # :linear (default) | :free

  step :company, label: "Company details" do
    attribute :name, :string
    attribute :subdomain, :string
    input :name
    input :subdomain
    validates :name, :subdomain, presence: true
  end

  step :plan, label: "Plan" do
    attribute :plan, :string
    input :plan, as: :radio_buttons, choices: %w[free pro]
    validates :plan, presence: true
  end

  step :billing, label: "Billing", condition: -> { data.plan == "pro" } do
    attribute :card_token, :string
    input :card_token
    validates :card_token, presence: true
  end

  step :team, label: "Invite your team" do
    structured_input :invites, repeat: 5 do |f|
      f.input :email, as: :email
      f.input :role, as: :select, choices: %w[admin member]
    end
  end

  # ONE atomic write at the finish. Reads everything from `data`.
  def execute
    company = Company.create!(name: data.name, subdomain: data.subdomain, plan: data.plan)
    Billing.create!(company:, token: data.card_token) if data.plan == "pro"
    data.invites.each { |i| company.invites.create!(email: i.email, role: i.role) }
    succeed(company).with_message("You're all set!")
  end
end
```

This is **Option A**: inline steps + a single final `execute`. Atomic, no orphans, nothing written mid-flow. The optional per-step `on_submit`/`on_rollback` hooks (§2.3) are for the niche cases that genuinely need real records mid-flow.

### 2.1 Core concepts

| Concept | Meaning |
|---|---|
| **`data`** | Everything the user has typed so far, auto-staged to the store after each step validates. Read-only snapshot in `condition:`, `on_submit`, and `execute`. This is the wizard's memory; it always exists, with or without `on_submit`. |
| **`persisted[:key]`** | Record(s) a **per-step `on_submit`** registered via the `persist` macro, keyed by step, tracked by GlobalID (rehydrated on resume, eligible for default destroy-cleanup). Only relevant when using `on_submit`; an `execute`-only wizard creates its records locally. |
| **`anchor`** | The existing record the wizard was launched against (see §3), declared with `anchored`. An input, not an output. **Raises `Plutonium::Wizard::NotAnchoredError` if the wizard isn't anchored** — never returns nil (calling it on a non-anchored wizard is a programming error). |
| **`step`** | A named screen with its own `attribute`/`input`/`validates`/`structured_input` (the existing field DSL), an optional `condition:`, and optional `on_submit`/`on_rollback` hooks. |
| **`using:`** (a `step` option) | Import a field surface (attributes + inputs + **validations** + **`form_layout`**) from a **model (record class)** instead of re-declaring it, with `fields:`/`only:`/`except:` selectors, `validate: false` (skip validation reuse) and `layout: false` (skip layout inheritance). Types/validations/field-universe come from the model; `<Model>Definition` is auto-resolved to overlay input styling. A `step` keyword option (not a block method — avoids the `Module#using` refinements clash); the block, if present, adds inline fields. Declaration reuse only — never the model's persistence. See §2.4. |
| **`review`** | A built-in terminal step that auto-summarizes collected `data` (via display components), lists invalid/unvisited steps as jump links, and gates Finish → `execute`. Optional custom block. See §2.5. |
| **`condition:`** | Lambda over `data` (and `anchor`) gating whether the step is included. Drives **subtractive** branching. Consistent with `form_layout`'s `condition:`. |
| **`execute`** | **At-end** hook, runs once after the last visible step, in one transaction. Returns an `Outcome` (`succeed`/`failed`) or raises to fail. **Use bang methods** (`create!`/`update!`); see §6.1. The default place to write. |
| **`on_submit`** | Optional **per-step** block (opt-in), run in its own transaction when the step completes — genuine save-as-you-go (writes and/or side effects). **Must use bang methods / raise to signal failure** (a non-bang `false` return advances silently — §6.1). Carries the cleanup cost in §2.3. |
| **`persist` (macro)** | Called inside `on_submit` to register the record(s) the engine should track for resume + cleanup → `persisted[:step_key]`. Accepts a record or a list. |
| **`on_rollback`** | Optional per-step compensating block (reads `persisted[...]`); how to undo this step on Cancel/abandonment. Defaults to destroying the tracked record(s). |
| **`navigation`** | `:linear` (default) or `:free`. Controls stepper jump behavior (see §7). |
| **`cleanup_after <ttl>`** | Idle TTL before the abandonment sweep reaps a session and rolls back its tracked records. Stamped per write as a concrete `expires_at`. `:never` opts out (records persist). Defaults to `config.wizards.cleanup_after`. See §2.3. |
| **`encrypt_data`** | Optional `encrypt_data true` to apply Rails 7 `encrypts` to the `data`/`persisted` payload (off by default), for flows that stage PII. See §8.1. |
| **`concurrency_key { … }`** | Optional block (Solid Queue–style) returning the value(s) a run is keyed by; ≤1 in-progress run per key (the keyed row is the lock, created at start). Omit → unlimited concurrent tokened runs. Identity source for §4. |
| **`one_time`** | Optional; with a `concurrency_key`, **retain** the completed row at the key → permanently blocks a restart (gate-able). Omit → row deleted on completion → repeatable. See §4.3/§9. |
| **`wizard_token`** | Context method — the per-run id (server-minted; identity for non-`concurrency_key`/guest runs). Available in `concurrency_key`. Not a pre-auth principal that survives login. |
| **`anonymous`** | Opt-in macro: the wizard may run without authentication (guest). Default = authentication required. Guest wizards may authenticate only at their terminal `execute`; never mid-flow. See §4.5. |

Steps reuse the existing field DSL verbatim — a step is essentially an interaction's field surface rendered on its own screen, fed through the same `form_layout` → form-rendering pipeline.

### 2.2 `data` vs `persisted`

The single most important distinction. The earlier design muddled them; they are separate:

- **`data`** is *input the user typed*. Always staged automatically. Never written by the author.
- **`persisted[:key]`** are *rows the author created and registered* via the `persist` macro inside an `on_submit` block.
- **`anchor`** is *an existing row the wizard was launched against*, never created by the wizard.

A wizard that **creates** a record has **no anchor**; a `on_submit` block that creates a row simply registers it under the step key — it does **not** "establish the anchor." The anchor only exists for wizards explicitly launched against an existing record.

### 2.3 Per-step work (opt-in) and cleanup

There is **no `commit` knob**. Timing is determined by *which hook you use*:

- **`execute`** is the **at-end** hook (default). One transaction at the finish. Atomic, no orphans, nothing written mid-flow. Use it for almost everything.
- **`on_submit`** is a genuine **per-step** hook (opt-in). It runs *when that step completes*, so a real record can exist mid-flow — needed only for the niche cases: handing off to an external system mid-flow (e.g. redirect to a payment provider that webhooks back), a reviewer/admin who must see partial submissions, or a step whose data is too large to carry in the session row.

A `on_submit` block may do more than create a record (side effects, jobs, API calls), so it isn't named `persist`. Inside it, call the **`persist`** *macro* to register the record(s) the engine should track for resume and cleanup; they become available as **`persisted[:step_key]`**.

```ruby
class CheckoutWizard < Plutonium::Wizard::Base
  cleanup_after 21.days        # idle TTL before the abandonment sweep (:never to opt out)

  step :order, label: "Your order" do
    attribute :sku, :string
    input :sku
    validates :sku, presence: true

    on_submit do
      order = Order.create!(sku: data.sku, status: :pending)
      persist order                  # register for tracking → persisted[:order]
      PaymentApi.authorize!(order)   # other side effects, not tracked
    end

    on_rollback { persisted[:order].destroy! }   # default already destroys tracked records
  end
end
```

Because `on_submit` runs immediately, it is **not atomic** across steps (HTTP can't hold a transaction across requests). That is the price of mid-flow real records, and it's why cleanup exists.

**`persist` (the macro) is what gets tracked.** It accepts a record or a list of records; the registered set is exposed as `persisted[:step_key]`:

- A registered **AR record** (or list) → tracked by GlobalID (rehydrated on resume; default cleanup destroys it).
- An `on_submit` that registers **nothing** (side-effect-only — an external API call, a job enqueue) → nothing is auto-tracked, and the engine has nothing to auto-destroy. You **must** supply an `on_rollback` block if the effect needs undoing — the engine never guesses how to compensate a non-record side effect.

**Cleanup / rollback.** The engine tracks the GlobalID of every record passed to `persist`, so it can undo them precisely — **no `draft` column on your models is required**:

- Each step may declare an `on_rollback do ... end` compensating block (reads `persisted[...]`). **Omitted → the engine destroys the tracked record(s)** (reverse order, in one transaction). Override when undo needs more than a destroy (refund a charge, call an external API), or when `on_submit` registered no record. **Caution:** the very case that motivates `on_submit` (a record other systems/users already reference mid-flow) is also where a default destroy-on-abandon can violate an FK or remove something already linked — supply an `on_rollback` that soft-deletes/detaches instead, or use `cleanup_after :never` for flows whose partials must persist.
- **`cleanup_after <ttl>`** — the **idle TTL** before the abandonment sweep reaps a session. It is stamped onto the row as a concrete **`expires_at` = now + ttl on every write**, so an actively-progressing wizard keeps pushing its expiry forward and a later change to the wizard's TTL never retroactively shifts existing rows. **`cleanup_after :never`** stores a null `expires_at`, opting the wizard out of sweeping entirely (long-lived resumable flows, where partial records persist by design). Defaults to the global `config.wizards.cleanup_after` when omitted. (There is no separate destroy/keep strategy: a TTL means "sweep and roll back"; `:never` means "keep.")
- **Triggers:** an explicit **Cancel** action in the wizard UI always runs rollback immediately, and the **abandonment sweep** runs it for idle `in_progress` rows past the TTL (then deletes the row).
- A per-step **failure** in `on_submit` only rolls back *that step's own* transaction; earlier steps remain and the user retries. Full cleanup fires only on Cancel or abandonment — never on a recoverable step error.

`execute`-only wizards need none of this: they're atomic, and abandonment leaves only the wizard's own session row (swept normally). `condition:` only ever reads `data` (never `persisted`), so branching is identical whether or not you use `on_submit`.

### 2.4 Field reuse — `using:` a model

A step needn't re-declare fields it can borrow from a **model (record class)** — the same instinct as nested-input reuse (and matching Plutonium's existing `structured_input …, using:` keyword). `using:` is a **`step` option** (not a block method — avoiding any clash with Ruby's `Module#using` refinements method); selectors pick a subset; the block, if given, adds inline fields on top.

```ruby
# whole-step import from a model (no block needed when using: supplies everything)
step :company, label: "Company details",
     using: Company, fields: %i[name subdomain email]

# mixing imported + wizard-local fields: using: option + a block for the extras
step :branding, label: "Branding", using: Company, only: %i[logo] do
  attribute :tagline, :string                        # plus a wizard-only field
  input :tagline
  validates :tagline, presence: true
end
```

> **Why a model, not a definition.** A `Plutonium::Resource::Definition` is an empty class with **no link to its model** — the model is always supplied by the controller at request time (`form_class.new(record, …)`), and the framework only ever binds *model→definition* (`"#{Model}Definition".constantize`). So a definition can't resolve its own model or its full (policy-derived) field list at class-load. The **model** is where types and validations live, so it's the reliable reuse target. The importer **auto-resolves `<Model>Definition` from the model** (the reliable forward direction) to overlay input styling — best-effort; nil is fine.

**The mechanism (model target):**

- **Field universe + types come from the model** — `Model.attribute_names` (the importable set) and `Model.attribute_types` (the cast types). Selectors `fields:`/`only:`/`except:` pick a subset.
- **Input styling** is overlaid from `"#{Model}Definition".safe_constantize` (its `as:`, options, labels) where present; no definition found → just model-derived inputs.
- **Validation** runs via a **transient (unsaved) `Model.new(data_slice)` → `valid?`**, importing the resulting errors **for the imported fields plus `:base`**.
- **Errors kept:** those on the **imported fields** *and* **`:base`** (model-level / cross-field rules) — `:base` renders as step-level (form-level) errors, the way forms show base errors today. **Errors on *other* attributes (columns this step never collects) are dropped** — this is exactly what prevents the classic "partial model `valid?` reports presence errors for fields the step doesn't have" problem: those errors exist but are filtered out, so they never block or surface.
- We deliberately **run `valid?` and filter** rather than clone validators: AR model validators can't be cloned cleanly (they depend on model internals/associations/callbacks). (ActiveModel has no native "validate only these attributes"; running-and-filtering is the pragmatic equivalent.)
- **`validation_context:`** — pass a context to run `valid?(context)` (e.g. a model that defines `validates ..., on: :step_company`), so authors can scope reused validations natively when the model supports it.
- **Residual caveats (smaller, after filtering):** a `:base` rule that references an attribute *not* in this step may fire spuriously or be unfixable here; conditional (`if:`) validations on *imported* fields may depend on uncollected ones; uniqueness validations hit the DB. When reused validations don't fit, use **`validate: false`** + inline `validates` for that step.
- **`form_layout` is inherited too** (from the resolved `<Model>Definition`). If it defines a `form_layout`, the step adopts it — **filtered to the imported fields**, and any imported fields not named in an explicit section fall into a trailing **ungrouped** section (mirroring the canonical `resolve_form_sections` leftover handling, so no imported field silently disappears). A step's **own inline `form_layout` overrides** the inherited one; **`layout: false`** opts out (default single grid).
- **`validate: false`** disables validation reuse — import only the field *declarations* (types, `as:`, options); you then write inline `validates` for that step. The escape hatch for when reused validations are too strict or too context-dependent.
- **Selectors:** `fields:` (alias `only:`) / `except:`.
- **Declaration reuse only** — `using:` never pulls in the model's persistence/callbacks. Data still stages into `data`; the wizard's own `execute`/`on_submit` does all writes (with bang methods). This preserves the "wizards don't delegate persistence" rule (§1).

### 2.5 Review step — `review`

A built-in **terminal** step that summarizes the flow and gates completion (keystone's review pattern, adapted to staged data):

```ruby
step :company do ... end
step :plan    do ... end

review label: "Review & submit"          # auto-summary + gated finish
# or, custom content:
review label: "Review & submit" do |r|
  r.summary                              # the auto-summary, if you still want it
  r.text "By submitting you agree to the terms."
end
```

- **Auto-summary** — renders a read-only recap of every *visible* prior step's `data` (and `anchor`), grouped by step with field labels, reusing Plutonium **display components** (the same field types/labels the steps declared, including `using:`-imported ones).
- **Outstanding items** — runs the §6.3 completeness check and lists any invalid/unvisited visible steps as "fix this" **jump links** back to the offending step.
- **Gated Finish** — the Finish button is disabled until all visible steps are valid; clicking it runs `execute`.
- **Optional block** for custom content; omit it for the pure auto-summary. A `review` step declares no fields of its own.
- **Terminal:** `review` must be the **last** step, and no `condition:` may make a step resolve *after* it. The engine **asserts this at boot** (raises on a wizard that declares a step following `review`, or whose branching could place one there), so "terminal" and branching can't contradict.

### 2.6 The `data` object (typed, dot-accessible, nil-safe)

`data` is **not** the raw JSON column. The wizard builds a **union schema** from *all* steps' attribute declarations, and `data` is an **ActiveModel::Attributes-backed snapshot** reconstituted from the JSON each request — so values are **cast to their declared types** and exposed as methods. Types come from:

- inline `attribute :name, :type` declarations;
- `using:` an **interaction** → its `attribute :x, :type` declarations;
- `using:` a **resource definition** → the **backing record class's** column/attribute types (`Model.attribute_types`), since definitions carry no types (§2.4).

So:

- `data.plan` returns the cast value (e.g. a real Boolean/Integer/Date, not a raw string); `data.invites` returns an **array of typed sub-objects** responding to the `structured_input`'s declared fields (`i.email`, `i.role`).
- The schema is the **union across steps**, so `data` exposes every declared attribute regardless of which step is current.
- **Not-yet-collected fields read as `nil`** (or the attribute's declared `default:`). Because `condition:` lambdas run against this snapshot at every transition — including before the deciding step has been filled — **`condition:` lambdas MUST be nil-safe** (e.g. `-> { data.plan == "pro" }` is fine since `nil == "pro"` is false; avoid `-> { data.plan.upcase == "PRO" }` which raises on nil). This rule applies equally in `on_submit`/`execute`, though those run after their data exists.
- `data` is a **read-only snapshot** in `condition:`/`on_submit`/`execute`; the engine stages writes from validated step input, not by mutating `data` directly.

---

## 3. Anchoring (launched against an existing record)

A wizard may be **anchored** to an existing record — analogous to `attribute :resource` in an interaction. The anchor is read-only context, available from any step (and `condition:`/`on_submit`/`execute`) via the **`anchor`** accessor. (It is *not* part of `persisted` — that holds only records the wizard creates.) Calling `anchor` on a wizard that wasn't declared `anchored` **raises `Plutonium::Wizard::NotAnchoredError`** rather than returning nil — anchored vs not is a static property of the wizard, so reaching for it when absent is a bug.

It's declared with **`anchored`**, an optional **`with:`** naming the allowed type(s):

```ruby
class ConfigureCompanyWizard < Plutonium::Wizard::Base
  anchored with: Company           # operates on a Company

  step :branding do
    attribute :logo, :string
    input :logo, as: :string
    on_submit { anchor.update!(logo: data.logo) }   # mutates the anchor; nothing new to track
  end

  def execute
    succeed(anchor)
  end
end
```

- **`anchored with: Company`** → a single concrete type.
- **`anchored with: [Company, Organization]`** → a polymorphic anchor: the wizard accepts any of the listed types (stored via the polymorphic `anchor_type`/`anchor_id` columns).
- **`anchored`** (no `with:`) → generic; the type binds at registration to whichever resource hosts it (shareable library wizard).
- **omit `anchored`** → no anchor (pure data → create flow).

### 3.1 Generic / shareable wizards

`anchored` with no `with:` leaves the type open so the wizard is reusable across resources — this is what makes wizards a shareable library, like generic interactions:

```ruby
class ArchiveWithReasonWizard < Plutonium::Wizard::Base
  anchored                   # type bound at registration to whichever resource hosts it

  step :reason do
    attribute :reason, :string
    input :reason, as: :textarea
    validates :reason, presence: true
  end

  def execute
    anchor.update!(archived_at: Time.current, archive_reason: data.reason)
    succeed(anchor)
  end
end
```

### 3.2 Anchor resolution per surface

The wizard body never cares where the anchor came from; the launch surface resolves it:

- **Record action** — auto-injected from the URL `:id`. Zero code.
- **Collection action / create flow** — no anchor; the wizard creates records it names itself.
- **Standalone with context** — a resolver block supplies it: `anchored(with: Organization) { Current.organization }`.
- **Standalone, none** — omit `anchored`.

---

## 4. Identity, concurrency & repeatability

These are **three orthogonal concerns** (do not conflate them — a wizard's anchor, in particular, does *not* determine any of them):

### 4.1 Identity — which run am I, how do I resume

Every wizard run is a **session row** with its own `instance_key`, carried in the URL. Resume = that URL, or the in-progress list (`where(owner: current_user, scope: tenant, status: :in_progress)`). The `instance_key` is:

- **`concurrency_key` set** → `SHA256(wizard, serialized(concurrency_key))` — a stable key (see §4.2).
- **omitted** → `SHA256(wizard, wizard_token)` — a fresh per-launch token (see §4.3), so every launch is a distinct run.

`owner`/`anchor`/`scope` are also stored as columns (for listing/queries); identity is the digest.

### 4.2 Concurrency — `concurrency_key { … }` (borrowed from Solid Queue)

An optional author block, `instance_exec`'d in the wizard/controller context (where `current_user`, `current_scoped_entity`, `anchor`, `wizard_token` are available), returning the value(s) the run is keyed by (records → GID, scalars → string, arrays joined):

```ruby
concurrency_key { current_user }                          # ≤1 in-progress per user
concurrency_key { anchor }                                # ≤1 in-progress per anchored record
concurrency_key { current_user || wizard_token }          # pre-auth-safe (token until login)
```

The keyed session row is **created at the start** (`status: in_progress`) and *is the lock*: a second launch with the same key **resumes that row instead of forking** — at most one in-progress run per key. Omit `concurrency_key` → unlimited concurrent runs (each tokened). *(This is what an explicit "singleton" is — author-chosen, not implicit.)*

### 4.3 Repeatability — `one_time` (retain-on-complete)

The keyed row blocks for its whole life: `in_progress` blocks concurrent starts; on completion its fate is the only difference between repeatable and one-time:

- **`one_time`** → the completed row is **retained** at the key → permanently blocks a restart (and is what the gate, §9, checks).
- **not `one_time`** → the row is **deleted** on completion → repeatable (run it again later, e.g. "import data").

`one_time` requires a `concurrency_key` (that's the stable row to retain); a run with no `concurrency_key` is tokened and always repeatable.

| wizard | `concurrency_key` | `one_time` | behaviour |
|---|---|---|---|
| onboarding | `{ current_user }` | yes | one in-progress per user; once done, never again |
| import data | `{ current_user }` | no | one at a time per user; re-runnable after each finishes |
| create company | — | — | unlimited concurrent drafts; always repeatable |

### 4.4 Tenancy (cross-cutting, automatic)

The portal's **`current_scoped_entity`** is **folded into the `concurrency_key` and the completion check automatically** (and stored as the `scope` column), so concurrency, completion, and the in-progress list are **tenant-isolated by default** — the author doesn't thread it. This makes per-membership fall out for free: in a tenant portal, `concurrency_key { current_user } + one_time` is automatically once per **(user, tenant)**.

### 4.5 Authentication & guest (`anonymous`) wizards

**Wizards require authentication by default** — entry without a `current_user` is rejected. A wizard opts into guest access with the **`anonymous`** macro. Wizards **never cross the auth boundary mid-flow**; the *only* boundary a guest wizard may cross is its **terminal `execute`** (e.g. a signup flow whose `execute` creates the account and logs in).

- **Default (authenticated)** → `current_user` required throughout; identity via `concurrency_key` (else a per-run id); **all session lookups are owner-scoped** (`where(owner: current_user)`), so a run id leaked in a URL can't be resumed by another user.
- **`anonymous`** → may run with no `current_user`; identity = a **server-minted, unguessable guest run id held in the Rails session** (an alphanumeric `SecureRandom.alphanumeric(32)` token — ~190 bits, URL-clean, not a UUID), namespaced per wizard (`session["plutonium_wizards"][<wizard_key>]`) — **not a cookie, and with no TTL**. The **row's `cleanup_after` → sweep is the authoritative lifetime**; the session id is just a session-scoped pointer to it. Session storage gives: browser-close ephemerality, **auto-clear on login/logout via Rodauth's `reset_session`** (confirmed: `rodauth-rails` maps `clear_session` → `reset_session`), and clearing on completion; the id is **never read from or written to a URL** (no leak surface). It guards only the user's *own* in-progress data (no cross-account exposure). `execute` *may* authenticate — and that login goes through **Rodauth, which rotates the Rails session, so fixation is handled**. There is **no** mid-flow owner-stamping, token-survives-login, or instance_key rekey. *(Authenticated repeatable runs keep their URL-carried per-run id, owner-scoped on the row.)*

**Mounting:** default wizards are portal-hosted (authenticated). An `anonymous` wizard needs a **public route** (pre-login), so `register_wizard` takes a `public:`/unauthenticated mount option used only for opted-in `anonymous` wizards.

**Context methods** exposed to the wizard/gate (and inside `concurrency_key`): `current_user`, `current_scoped_entity` (tenant/scope), `anchor` (resolved record, §3), and `wizard_token` (the per-run id; for guest/repeatable identity — *not* a pre-auth principal that survives login).

On resume the engine restores the cursor + `data` and lazily rehydrates `persisted[:key]` from stored GlobalIDs on first access (memoized per request — a request that never reads `persisted` issues no `GlobalID.locate`).

---

## 5. Registration & launch surfaces

Wizards are **portal-hosted** — they run inside a Plutonium portal, exactly like resources, so they inherit the portal's authentication, tenant **scoping entity**, layout, and Phlex rendering. (Main-app / non-portal standalone wizards are out of scope for v1 — §16.) Two ways a wizard reaches a user within a portal; both synthesize real Plutonium **actions** under the hood (policy gating, buttons, placement all come for free).

### 5.1 On a resource — the `wizard` DSL in a definition

A **new** `wizard` macro (not an `action` overload):

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard               # anchored → record action
  wizard :onboard,   CompanyOnboardingWizard              # no anchor → resource (collection) action
  wizard :archive,   ArchiveWithReasonWizard, record_action: true   # generic wizard bound to Company here
end
```

- The `wizard` macro registers the wizard **and synthesizes the launching action(s)** — sugar over the Action system.
- **Placement mirrors interactions**: anchored-to-this-model → **record** action; no anchor → **resource** (collection) action. Inference parallels interactions (`attribute :resource` / neither), with `record_action:` / `collection:` overrides. **Bulk wizards (operating on many records) are not supported** — wizards are inherently per-instance flows; use a bulk interaction instead.
- **Authorization mirrors actions**: a resource policy predicate gates it (`def configure? = update?`). Generic wizards derive a default predicate name from the registration key.

### 5.2 Portal-level — `register_wizard` in a portal engine

For a wizard not tied to a single resource (e.g. onboarding), register it **in the portal engine's routes**, alongside `register_resource`:

```ruby
# packages/admin_portal/config/routes.rb (inside the portal engine)
PlutoniumPortal.routes.draw do
  register_wizard OnboardingWizard, at: "onboarding"            # portal-relative, authenticated
  register_wizard GuestSignupWizard, at: "signup", public: true # anonymous → public (pre-login)
end
```

This draws an authenticated wizard's step routes **within the portal** (so they get the portal's scope/auth/layout) and provides a path helper. The wizard runs through a portal-hosted wizard controller (the `Plutonium::Wizard::Controller` concern mixed into the portal's controller, like resource controllers). `scope_gid` comes from the portal's `scoped_entity` when the portal is entity-scoped.

**Public mount (`anonymous` only).** Because a portal engine is mounted *inside* the host's auth constraint (`constraints Rodauth::Rails.authenticate(:user) { mount … }`), a route drawn in the portal is unreachable pre-login. A guest (`anonymous`) wizard therefore takes `public: true` (the default for `anonymous`), and `register_wizard` draws its route on the **main application's** route set, outside that constraint, dispatching to a synthesized top-level `WizardsController` (full Plutonium controller stack + `Plutonium::Auth::Public`, rendered full-page with a standalone layout). A non-`anonymous` wizard may not be mounted public, and an `anonymous` wizard may not be mounted authenticated — both raise.

Portal-level wizards have no resource policy, so they're gated by a **wizard-level `authorize?` hook** checked before entry/each request:

```ruby
class OnboardingWizard < Plutonium::Wizard::Base
  def authorize? = current_user.present? && !current_user.onboarded?
end
```

Returning false → `ActionPolicy::Unauthorized` (→ 403, via the existing rescue). Resource-attached wizards use their action's policy predicate instead (§5.1); the `authorize?` instance method is the portal-level counterpart, and may also be defined on any wizard as an extra gate. (A block-form `authorize { … }` macro is a possible future nicety; v1 uses the plain `def authorize?` method.)

### 5.3 Synthesized routes

| Launch | URL shape |
|---|---|
| Record-anchored | `/companies/:id/wizards/configure/:step` |
| Collection (create, singleton) | `/companies/wizards/onboard/:step` |
| Collection (tokened, opt-in) | `/companies/wizards/onboard/:token/:step` |
| Standalone | `/welcome/:step` |

`GET :step` renders the step; `POST` advances. The instance key is derived from the URL (anchor id and/or token) + current user/cookie.

---

## 6. Runtime

A **single controller** (`Plutonium::Wizard::Controller`) drives every wizard regardless of surface. Per request:

1. **Resolve instance** from the URL (anchor id and/or token) + current user/cookie → load or create the `plutonium_wizard_sessions` row via the **Store**.
2. **Compute the visible step path** by evaluating each step's `condition:` against `data` (subtractive branching), then locate `current_step`. The path is recomputed each transition from the answer map — never stored as a fixed list — so branching stays correct as answers change.
3. **Dispatch on `_direction`** (submit carries intent separate from step):
   - **`next`**: validate the current step's fields → on success, stage `data`; if the step has a `on_submit`, run it in its own transaction (see §6.1) and track GIDs of any records passed to the `persist` macro; advance to the next visible step. On failure, re-render with errors and **input preserved**.
   - **`back`**: **no validation**, just move the cursor to the previous visible step. Never discards `data`.
   - **`cancel`**: run cleanup (§2.3) — `on_rollback`/destroy tracked records — then delete the session row and redirect.
   - on the **last** step, `next` **finalizes** (see §6.3): assert completeness, prune branch-hidden data, then run **`execute`** in one transaction. On success: mark the row `completed`, **clear `data`/`persisted`**, redirect (PRG) to the outcome's target; record a one-time completion if applicable.
4. **`pre_submit`** is honored exactly as today for in-step dynamic/dependent fields (reuses the existing mechanism).
5. **Entry authorization** — every request first checks the wizard's `authorize?` hook (§5.2) and/or the resource action policy (§5.1); failure → 403.

### 6.1 `on_submit` / `execute` failure semantics — **use bang methods**

The engine detects failure by **a raised exception**, not by a return value. So inside `on_submit` and `execute` you **must use bang persistence methods** — `create!`, `update!`, `save!`, `destroy!` — so a validation/DB failure *raises*. This is a hard rule:

```ruby
on_submit do
  order = Order.create!(sku: data.sku)   # ✓ raises ActiveRecord::RecordInvalid on failure
  persist order
end
```

> **Footgun:** non-bang `create`/`save`/`update` return `false` on failure **without raising**. The engine can't see that, so it would treat the step as **successful and advance** — silently losing the data and leaving no record. Always use the bang form (or explicitly raise; see below).

**What the engine catches (both `on_submit` and `execute`, each in a transaction):**
- **`ActiveRecord::RecordInvalid`** → roll back; map `e.record.errors` onto the step's form so the user sees **field-level** errors; stay on the step with input intact.
- **`Plutonium::Wizard::StepError`** (provided) — for a custom, non-AR failure → roll back; re-render the step with the message. Use this for external-service failures (payment, API) that aren't a `RecordInvalid`.
- Any **other `StandardError`** → roll back and re-raise (a real 500 — the engine doesn't swallow unexpected bugs).

**The `fail!` macro** is the ergonomic way to raise `StepError` from `on_submit`/`execute` (no need to reference the class):

```ruby
on_submit do
  result = PaymentApi.charge(data.card_token)
  fail!("Payment was declined") unless result.ok?      # → base error, rolls back, stays on step
  persist Order.create!(charge_id: result.id)
end
```

- `fail!("message")` → base (form-level) error.
- `fail!(:card_token, "is invalid")` → field-level error on that attribute.

It's just sugar over `raise StepError` (with optional attribute), so it composes with the catch rules above.

The wizard **never advances past a failed `on_submit`**. Earlier committed steps are untouched (undo them via Cancel → cleanup, not via this failure).

**`execute`** runs in one transaction at the finish and signals failure either way: **return `failed(errors)`** (interaction-style) **or raise** (`RecordInvalid`/`StepError`, same handling as above). On failure the row reverts `completing → in_progress` (§6.2) and the last step / review re-renders with the error; nothing is committed.

### 6.2 Anti-double-commit (history *and* concurrency)

Two distinct protections:

- **History replay** — on successful `execute`, the instance state is cleared and the response is a redirect (PRG), so a back-button replay can't re-run `execute`.
- **Concurrent submits** (double-click Finish, two tabs) — finalize performs a **locked status transition** before running `execute`: `row.with_lock { raise AlreadyFinalizing unless row.status == "in_progress"; row.update!(status: "completing") }`. The loser of the race sees the row already past `in_progress` and bails (redirecting to the completed outcome rather than re-running writes). `execute` runs only for the winner; on success the row moves `completing → completed`, on failure it reverts to `in_progress` so the user can retry. This closes the window PRG alone can't.

### 6.3 Finalize preconditions (completeness & pruning)

Before `execute` runs, the engine:

1. **Asserts completeness** — every *currently-visible* step (per the recomputed path) must have been visited and validated. Because branching can change the visible set as answers change, this guards against a user reaching the end with a now-required step never filled. If an unvisited/invalid visible step exists, the wizard redirects the user to the first such step rather than running `execute`.
2. **Prunes branch-hidden data** — `data` belonging to steps that are *not* in the currently-visible path (e.g. step B answered, then step A changed so B is now skipped) is dropped before `execute`, so `execute` sees only data for steps that actually apply. (Pruning happens on a working copy at finalize; the stored `data` is the source of truth until completion clears it.)

---

## 7. UI

Rendering reuses existing components — no parallel UI stack.

- **`Plutonium::UI::Page::Wizard`** wraps the existing form rendering for the current step (the same `attribute`/`input`/`structured_input` → `form_layout` → form pipeline interactions already use).
- **Stepper component** shows all visible steps with state (completed / current / upcoming):
  - In `:linear`, completed (visited) steps are clickable — jumping back to a visited step does **not** validate; **upcoming / branch-gated steps are disabled** until reachable.
  - In `:free`, any **currently-visible visited** step is clickable.
  - **Forward jumps to unvisited steps are never allowed** — they may depend on undecided data.
  - **Branch-hidden visited steps** (a step you filled, then a later answer change made its `condition:` false) are **dropped from the stepper immediately** — they're no longer in the visible path, so they're neither shown nor clickable, and their data is pruned at finalize (§6.3). The stepper always reflects the *currently*-visible path, recomputed each render.
- **Nav buttons**: Back / Next / Finish, rendered by step position, plus **Cancel** (triggers cleanup §2.3). Submit carries `_direction` (`next` / `back` / `cancel`).
- A wizard launched as a **resource action** renders inside the existing modal/turbo-frame flow; **standalone** renders **full-page**. Same page class, different chrome — the surface adapter decides.

Turbo behavior follows the existing interactive-action conventions (re-render with `:unprocessable_entity` on invalid; morph-friendly markup to preserve local UI state across re-renders).

### 7.1 Per-step `form_layout` sectioning

A step is its own form, so each step may section its fields with the existing **`form_layout`** DSL declared **inside the step** (scoped to that step's fields):

```ruby
step :company, label: "Company details" do
  attribute :name, :string
  attribute :legal_name, :string
  attribute :street, :string
  attribute :city, :string
  input :name
  input :legal_name
  input :street
  input :city

  form_layout do
    section :identity, :name, :legal_name, label: "Identity", columns: 2
    section :address,  :street, :city,     label: "Address", collapsible: true
  end
end
```

This reuses the §form-sectioning pipeline verbatim (`Section`/`ResolvedSection`, columns, collapsible, section `condition:`) — only the *scope* changes from class-level (one form) to per-step. Steps remain the top-level grouping; `form_layout` sub-groups *within* a step. A step without `form_layout` renders as one default grid, exactly like an interaction form today.

**Resolution order for a step's layout:** inline `form_layout` in the step (wins) → else the `form_layout` **inherited from a `using:` source** (filtered to the imported fields; `layout: false` to skip, §2.4) → else the default single grid.

### 7.2 Repeatable, structured & nested fields

Because a step uses the same field DSL and form pipeline, wizards inherit repeatable/structured inputs for free:

- **`structured_input ..., repeat: N`** (classless repeatable groups) — values serialize into the step's `data` as an array of hashes, reachable as `data.<name>` (a collection) in `condition:`/`on_submit`/`execute`.
- **Nested resource fields** (`has_many`/`has_one`) via the existing `RendersNestedResourceFields`, and the existing Stimulus repeater controls (add/remove/restore) work inside a step unchanged; `pre_submit` still drives dynamic in-step updates.

**Resume implication:** repeated values live in the JSON `data` column, so the step form must **repopulate its repeater rows from staged `data` on GET** (re-rendering the correct number of rows with their values), not only on a failed submit. This reuses the existing repeater rendering — it just must be seeded from the staged collection. The JSON column round-trips nested arrays/hashes.

---

## 8. Storage

**DB-only.** A single framework-owned table; **no changes to host models.** The session/cookie store is *not* shipped (Plutonium already manages schema, so "zero schema" buys little; DB-backed gives uniform resume across devices, an "in-progress wizards" listing, and durable one-time completions, all in one code path). The **Store port** abstraction is retained so tests get a fast **in-memory adapter** and a future session/Redis adapter stays possible.

### 8.1 Table — `plutonium_wizard_sessions`

```ruby
create_table :plutonium_wizard_sessions do |t|
  t.string :wizard,   null: false                # "CompanyOnboardingWizard"
  t.string :status,       null: false, default: "in_progress"   # in_progress | completing | completed
  t.string :current_step

  # Identity — a deterministic digest: either of the serialized concurrency_key
  # (tenant folded in) or of the wizard_token (§4). A single unique column is
  # required because nullable polymorphic columns can't enforce the singleton
  # rule: Postgres/SQLite treat NULL ≠ NULL in unique indexes.
  t.string :instance_key, null: false

  # Polymorphic refs — for querying/listing and rebuilding context (NOT identity).
  # *_id is string-typed to accommodate bigint or uuid host PKs.
  t.string :owner_type
  t.string :owner_id           # the user (nullable for pre-auth)
  t.string :anchor_type
  t.string :anchor_id         # the anchor (nullable)
  t.string :scope_type
  t.string :scope_id          # the portal scoping entity / tenant (nullable)
  t.string :token              # pre-auth / tokened concurrent instances (nullable)

  t.json   :data,            null: false, default: {}  # staged field values  (jsonb on PG — see note)
  t.json   :tracked_records, null: false, default: {}  # GlobalIDs of created records, by step key
  # NOTE: column is `tracked_records`, NOT `persisted` — an AR attribute named `persisted`
  # collides with ActiveRecord::Persistence#persisted? (DangerousAttributeError). The
  # author-facing accessor stays `persisted[:key]` (§2); the Store maps it to this column.

  # Concrete expiry, stamped = now + cleanup_after on EVERY write (nil = :never).
  # Frozen per row so the sweep is a plain `expires_at < now` and a wizard's TTL
  # change never retroactively shifts existing rows.
  t.datetime :expires_at
  t.datetime :completed_at
  t.timestamps

  t.index :instance_key, unique: true                                  # identity / resume
  t.index [:status, :expires_at]                                       # sweep
  t.index [:owner_type, :owner_id, :status]                            # "my in-progress wizards"
  t.index [:scope_type, :scope_id, :status]                            # "this tenant's in-progress wizards"
  t.index [:wizard, :anchor_type, :anchor_id, :status]                 # once-per-anchor completion
end
```

One table serves everything:

- **Resume** = look up the row by `instance_key` (single-column unique index). The key is the concurrency_key digest (tenant folded in) or the wizard_token digest, so an existing `in_progress` keyed row IS the lock — a second launch resumes it.
- **One-time check** = does a `completed` row exist at the recomputed `instance_key` (`completed?(instance_key:)`) — see §9.
- **In-progress listing** = `where(owner: current_user, status: "in_progress")`; per-tenant = `where(scope: current_scope, status: "in_progress")`.
- **Multi-tenancy** = the current portal **scoping entity** is folded into `instance_key` (§4) and stored as `scope_type`/`scope_id`, so the same user running the same non-anchored wizard in two tenant portals gets **two distinct rows** rather than colliding. Blank for non-scoped (e.g. main-app) flows.
- **Sweep** = `where(status: ["in_progress", "completing"]).where("expires_at < ?", now)` (rows with null `expires_at` — `cleanup_after :never` — are skipped). The `completing` inclusion reaps rows where a finalize crashed mid-flight (§6.2). For each, run the wizard's **cleanup** (§2.3 — `on_rollback`/destroy tracked records) and then delete the row; **never** touch `completed`. `expires_at` is re-stamped (`now + cleanup_after`) on every write, so an actively-progressing wizard keeps pushing its expiry forward. Because the row stores the GIDs of records registered via the per-step `persist` macro, cleanup needs no `draft` column on host models.
- On completion of a one-time wizard, keep the row as the marker but **null out `data` / `tracked_records`** (privacy + size).

**Column types.** The migration uses adapter-appropriate JSON — **`jsonb` on PostgreSQL** (better round-tripping/indexability), `json` elsewhere. `data`/`persisted` are never queried *inside* (we key on columns), so this is purely a fidelity choice.

**SweepJob must be scheduled — load-bearing for save-as-you-go.** For `execute`-only wizards, an unscheduled sweep merely leaves stale *session rows* (harmless). But for **`on_submit` (save-as-you-go) wizards, the sweep is the only thing that cleans up abandoned real domain records** — if the host never schedules `Plutonium::Wizard::SweepJob`, those partial records accumulate forever. The install docs must make scheduling it a required step for any app using `on_submit`, and the `register_wizard`/`wizard` macros should warn (dev-mode log) if an `on_submit` wizard is registered without a configured sweep.

**Optional encryption.** A wizard may declare `encrypt_data true` to apply Rails 7 `encrypts` to the `data`/`tracked_records` columns (off by default), for flows that stage PII. `owner`/`anchor`/`scope`/`token` stay plaintext (they're queried).

### 8.2 Files

File uploads cannot sit in the JSON column → use ActiveStorage direct upload (the existing `uppy_tag`) and store the blob's `signed_id` in `data`. Sidesteps the classic "abandoned wizard leaks temp files" problem.

### 8.3 Store interface (sketch)

```ruby
# Plutonium::Wizard::Store::Base — port
#   read(instance_key)               → State | nil
#   write(instance_key, state)       → State   (upsert; sets owner/anchor/token + expires_at = now + cleanup_after)
#   complete(instance_key)           → marks completed, nulls data/tracked_records columns (one-time retain)
#   clear(instance_key)              → deletes the row (repeatable completion + cancel)
#   completed?(instance_key:)        → bool   (one-time check — existence of a completed row at the key)
#   in_progress_for(owner, scope:)  → [State]  (listing; scope: REQUIRED keyword —
#                                      non-nil narrows to that tenant, explicit nil = no filter)
#
# Public/ergonomic API:
#   Plutonium::Wizard.in_progress_for(view_context) → [Resume::Entry]
#     takes the view_context (as interactions do) and derives owner = current_user,
#     scope = current_scoped_entity (when scoped_to_entity?, else nil), then calls
#     the low-level store query with scope passed explicitly.
#
# State carries: wizard, current_step, data, persisted (rehydrated records),
#                owner, anchor, token.
#
# Plutonium::Wizard::Store::ActiveRecord — shipped (backed by the table)
# Plutonium::Wizard::Store::Memory       — tests / future adapters
```

---

## 9. One-time wizards (onboarding)

A one-time wizard needs a **durable completion marker** — you cannot remember "done forever" in a session. The DB store already provides it (a `completed` row).

```ruby
class OnboardingWizard < Plutonium::Wizard::Base
  concurrency_key { current_user }   # the stable row to retain (tenant folded in, §4.4)
  one_time                            # retain the completed row → never again

  # ... steps ...

  def execute
    current_user.update!(onboarded_at: Time.current)
    succeed.with_message("Welcome aboard!")
  end
end
```

- **Completion** = the instance row reaching `status: :completed`, **retained** at the wizard's `instance_key` (`one_time` keeps it instead of deleting).
- **`one_time` requires a `concurrency_key`** — that's the stable key the retained marker lives at (and the key the gate recomputes). `concurrency_key { anchor }` keys completion by the anchor ("set up *this* workspace once"); `concurrency_key { current_user }` keys it per user; the **tenant is folded in automatically** (§4.4).
- **Gating / auto-trigger** via a controller/portal concern:

  ```ruby
  # in a portal or ApplicationController
  ensure_wizard_completed OnboardingWizard   # before_action: redirect into the wizard until done
  ```

  The gate **recomputes the wizard's `instance_key`** from its `concurrency_key` (resolved against the host controller — `current_user`/`current_scoped_entity`/`anchor`/custom methods are available) and checks `completed?(instance_key:)`. This digest MUST match the runner/driving one (both go through `Plutonium::Wizard.compute_instance_key`), or gating silently breaks. Only one-time wizards are gateable — gating any other raises. After login, an un-onboarded user hits the gate → redirected to the wizard → on completion, the marker is retained and the user is bounced to the original destination (PRG). Completed users never see it again.

Dismissible / "remind me later" onboarding is a **follow-up**, not v1.

---

## 10. Migrations — gem-shipped, per-feature, opt-in

Migrations ship **in the gem** and Rails runs them **in place** (not copied into the host app). They are organized **per feature** so each can be gated independently.

```
plutonium-core/db/migrate/
  wizard/        # 20260615######_create_plutonium_wizard_sessions.rb
  <future>/      # future features drop migrations here
```

```ruby
# lib/plutonium/railtie.rb
# MUST run after the host's config/initializers/* so config.wizards.enabled is set.
# Railtie initializers run BEFORE app initializers; :load_config_initializers is the
# Rails initializer that loads config/initializers/*, so we hook after it. Migration
# paths are read lazily at rake time (after full boot), so this timing is in scope.
initializer "plutonium.migrations", after: :load_config_initializers do |app|
  Plutonium::Migrations.enabled_paths.each do |path|     # reads config flags — now set
    # Append to the configured database's migration paths (multi-db aware), not just
    # the global one, so the table lands on the intended connection.
    db = Plutonium.configuration.wizards.database          # default :primary
    db_config = app.config.database_configuration_for(db)  # resolve the connection's migrations_paths
    (db_config.migrations_paths ||= []) << path
    app.config.paths["db/migrate"] << path if db == :primary
    ActiveRecord::Migrator.migrations_paths << path unless
      ActiveRecord::Migrator.migrations_paths.include?(path)
  end
end
```

> **Why `after: :load_config_initializers`:** the host enables the feature in `config/initializers/plutonium.rb`, but railtie initializers run *before* app initializers — so reading `config.wizards.enabled` at plain railtie-init time would always see the `false` default and silently skip the migration. Hooking after `:load_config_initializers` guarantees the flag is set first.

```ruby
# host app: config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.wizards.enabled = true            # false by default; registers db/migrate/wizard → rails db:migrate runs it
  config.wizards.cleanup_after = 14.days   # global default idle TTL for the sweep
  config.wizards.database = :primary       # which DB the wizard table lives on (multi-db apps)
end
```

Wizard config is **namespaced** under `config.wizards` (`enabled`, `cleanup_after`, `database`), following the per-feature pattern so future features get their own namespace.

**Multi-database & `db:schema:load` (review #7).** Gem-loaded migrations are kept (your preferred zero-copy DX), with these clarifications:
- **Which DB:** `config.wizards.database` (default `:primary`) names the connection; the gem migration path is registered on **that database's** `migrations_paths`, so multi-db apps put the table on the right connection rather than always the primary. `rails db:migrate:<name>` picks it up.
- **`schema.rb`/`structure.sql` round-trip:** once `rails db:migrate` runs, the table is dumped into the host's schema file like any other — so **`db:schema:load` on fresh/CI databases recreates it normally** (it loads from the dumped schema, not from the gem). The gem path only matters for *running pending migrations*, not for schema load.
- **`db:migrate:status`** shows the migration's file living in the gem (and "file missing" if the gem is later removed) — cosmetic, as previously noted.

- `Plutonium::Migrations` is a registry mapping feature → gem subdirectory, filtered by config (reads `config.wizards.enabled`). Each migration keeps its own timestamp version (Rails scans all registered paths and orders by version).
- `config.wizards.cleanup_after` is the global default idle TTL for the abandonment sweep, overridable per wizard via `cleanup_after`. The sweep runs as a scheduled job/rake task (`Plutonium::Wizard::SweepJob`) the host wires up.
- **`config.wizards.enabled` defaults to `false`** (opt-in). Wizards are core *code*, but the *table* only materializes when enabled — apps not using wizards stay schema-clean.
- Enable later → the migration appears as pending and runs. Disable → the path isn't added; the existing table is left alone (never auto-dropped).
- Existing copy-generators (`pu:rodauth`, `pu:invites`) keep their template approach (they're app-customized); the wizard table is framework-internal, so gem-loaded is correct.
- Trade-off accepted: `db:migrate:status` shows the migration file living in the gem; if the gem is removed it reads as "file missing" until the table is dropped — standard for gem-shipped migrations.

---

## 11. No generator (v1)

A wizard is a plain Ruby class, exactly like an **interaction** — and interactions have **no generator**. A generator would mostly emit a stub the author immediately rewrites (steps can't be expressed on the CLI); its only real value is the one-line registration wiring. That doesn't justify building/testing/maintaining a generator, and "author by hand, register in one line" is the established interaction precedent. Dummy-app test wizards are hand-written, consistent with how dummy-app interactions are already created.

Revisit a generator later only if the wiring proves annoying in practice.

---

## 12. Module / namespace map

```
Plutonium::Wizard::Base            # author class: steps DSL, anchored, navigation, cleanup_after, one_time, authorize?, execute
Plutonium::Wizard::Step            # step metadata: key, label, condition, fields definition, on_submit/on_rollback blocks
Plutonium::Wizard::ReviewStep      # terminal review step: auto-summary + outstanding-items + gated finish
Plutonium::Wizard::FieldImporter   # resolves `using:` — imports attributes/inputs/form_layout from an interaction/definition; validates via source.new(data_slice).valid? (unless validate: false)
Plutonium::Wizard::DSL             # class macros: step/review/anchored/navigation/cleanup_after/concurrency_key/one_time/encrypt_data (mixed into Base)
Plutonium::Wizard::InstanceKey     # identity digest builders: .concurrency(name, key_values) / .tokened(name, token)
Plutonium::Wizard.compute_instance_key  # shared digest used by BOTH runner/driving and the gate (must stay identical)
Plutonium::Wizard::Runner          # navigation/path computation, validation, on_submit, execute orchestration
Plutonium::Wizard::State           # value object: cursor, data, persisted (GIDs)
Plutonium::Wizard::Store::Base     # storage port
Plutonium::Wizard::Store::ActiveRecord  # shipped DB store
Plutonium::Wizard::Store::Memory   # in-memory test adapter
Plutonium::Wizard::Session         # AR model for plutonium_wizard_sessions
Plutonium::Wizard::Controller      # single controller mixin (all surfaces)
Plutonium::Wizard::Gate            # ensure_wizard_completed concern
Plutonium::UI::Page::Wizard        # page class (reuses form/page pipeline)
Plutonium::UI::Wizard::Stepper     # stepper component
Plutonium::Definition::Wizards     # the `wizard` macro (mirrors Definition::Actions)
Plutonium::Routing  (register_wizard)   # standalone mount
Plutonium::Migrations              # per-feature migration-path registry
Plutonium::Configuration#wizards   # namespaced config: .enabled (opt-in flag), .cleanup_after (default sweep TTL), .database (multi-db target)
Plutonium::Wizard::SweepJob        # reaps idle abandoned sessions (runs cleanup, deletes rows)
Plutonium::Wizard::NotAnchoredError # raised by `anchor` on a non-anchored wizard
Plutonium::Wizard::StepError       # raise in on_submit/execute for a custom (non-RecordInvalid) step failure → base error
```

Reused as-is: interaction `Outcome`/`Response`, the `attribute`/`input`/`validates`/`structured_input` field DSL, `form_layout`, form rendering, the Action system, policies, `pre_submit`.

---

## 13. Naming — glossary (all decided)

All names below are **decided** — kept here as the canonical glossary:

- anchor: declared with **`anchored with: Type`**, value read via the **`anchor`** accessor (raises `NotAnchoredError` if absent)
- tracked created records: **`persisted[:key]`**
- staged input: **`data`**
- per-step action block: **`on_submit`**; tracking macro **`persist`**; compensator **`on_rollback`**
- at-end hook: **`execute`**; error-raising macro **`fail!(message)`** / **`fail!(attribute, message)`** (sugar over `StepError`)
- TTL keyword: **`cleanup_after <ttl>/:never`**; global **`config.wizards.cleanup_after`**
- instance disambiguation segment: **`token`**
- navigation intent param: **`_direction`** (`next`/`back`/`cancel`)
- config namespace: **`config.wizards.enabled`**

> Note: `persisted[:key]` reads adjacent to ActiveModel's `persisted?` — unrelated; the wizard accessor is a hash of tracked records, not a persistence predicate. Flagged so authors aren't confused; kept because it best describes "records this step persisted."

---

## 14. Testing strategy

- **Unit (fast, DB-free)** via the **in-memory Store adapter**: path computation (subtractive branching, back), per-step validation gating, `on_submit` transaction + rollback-on-raise, `persist`-macro tracking, cleanup (Cancel + sweep), `execute` → completion → state cleared, anti-double-commit, one-time gating logic, anchor resolution.
- **Integration** in `test/dummy` against the real DB store + migrated table: one sample wizard exercised across each surface — record action, collection-create, standalone, one-time/gated — mirroring `test/integration/admin_portal/*`. Sample wizards hand-written (no generator).
- **Appraisal** across `rails-7`, `rails-8.0`, `rails-8.1`.

---

## 15. Docs & skill

- New skill `.claude/skills/plutonium-wizard/SKILL.md` (same frontmatter/structure as other `plutonium-*` skills); add it to the umbrella `plutonium` skill's skill-map. (Takes effect on gem release.)
- Docs: a guide `docs/guides/wizards.md` and reference pages under `docs/reference/wizard/` (DSL, anchoring & resume, storage/config, registration & launch, one-time). Add to the VitePress nav.

---

## 16. Out of scope / follow-ups

- **Main-app / non-portal standalone wizards** — v1 hosts wizards **inside portals only** (they inherit portal auth/scoping/layout/rendering). A non-portal mount is a possible follow-up.
- **Bulk wizards** (operating on many records at once) — explicitly **not supported**; use a bulk interaction. Wizards are per-instance flows.
- Wizard generator (`pu:wizard`).
- Dismissible / "remind me later" onboarding.
- Explicit non-linear **jump** escape hatch (`then:`/`goto`) — only if a real branching/loop need appears; would require a guaranteed default.
- Session / Redis store adapter (the port stays open for it).
- Parallel / Petri-net style multi-active-step flows.

---

## 17. Decision log (resolved during brainstorming)

1. **Use cases:** general-purpose — multi-model create + single complex object + branching.
2. **Step model:** inline blocks (Option A ergonomics), one class. **Not** interaction-delegation (interactions own endpoints/redirects). Steps may **`using:`** a **model** to import a field surface (attributes+inputs+**validations**+**`form_layout`**) without re-declaring — types + field universe from the model (`Model.attribute_types`/`attribute_names`), `<Model>Definition` auto-resolved to overlay input styling (definitions have no model link, so model→definition is the only reliable direction). Validation via transient `Model.new(data_slice).valid?` keeping errors on imported fields **+ `:base`**, `validate: false` to skip. Inherited `form_layout` filtered to imported fields (+ ungrouped leftover), inline-override, `layout: false` opt-out. **Interaction targets are not supported** — model only. Declaration reuse only, never persistence (§2.4).
2a. **Review step:** built-in **`review`** terminal step (auto-summary via display components, outstanding-item jump links, gated finish → `execute`); adapted from keystone (§2.5).
3. **Writes:** `execute` is the at-end hook (default, atomic). `on_submit` is an opt-in **genuine per-step** action hook for niche mid-flow-record cases — no `commit` knob (it was incoherent). Inside `on_submit`, the **`persist` macro** registers record(s) to track → `persisted[:step_key]`. Cleanup: per-step `on_rollback` (defaults to destroying tracked records; required if `on_submit` registers none), single **`cleanup_after <ttl>/:never`** knob (no destroy/keep strategy — a TTL means sweep+on_rollback, `:never` means keep; idle from `updated_at`, global default `config.wizards.cleanup_after`), triggered by Cancel + abandonment sweep; engine tracks GIDs so **no `draft` column on host models** is required.
4. **`data` (always staged) vs `persisted` (created/tracked) vs `anchor` (existing-record input)** are distinct.
5. **Anchoring:** declared with **`anchored`** + optional **`with:`** — `anchored with: Company` / `anchored with: [Company, Organization]` (polymorphic) / `anchored` (generic) / omit; value read via the **`anchor`** accessor; resolved per surface; always part of the instance key when present. **Bulk not supported.**
6. **Resume:** instance key from URL + user (token from URL for authenticated runs, Rails session for guest runs); singleton per `(user, wizard)` default; tokened opt-in; resume confirmation; guest identity via the Rails session.
7. **Registration:** new `wizard` DSL in definitions (synthesizes actions; placement mirrors interactions); `register_wizard` for standalone.
8. **Navigation:** per-wizard `:linear` (default) / `:free`; back never validates; forward only through validation; branch-gated steps disabled in the stepper.
8a. **Finalize preconditions (§6.3):** before `execute`, assert every currently-visible step is visited+valid (else redirect to it), and prune `data` for branch-hidden steps.
8b. **Authorization:** resource wizards use the action policy predicate; standalone wizards use a wizard-level `authorize?` hook (checked per request).
9. **Storage:** DB-only, single `plutonium_wizard_sessions` table; **polymorphic** owner/anchor/**scope** (for listing/queries) + a derived unique **`instance_key`** digest (for identity, since nullable polymorphic cols can't enforce the singleton); the **portal scoping entity is folded into the key + stored** so the same user's same non-anchored wizard doesn't collide across tenants; concrete **`expires_at`** stamped per write (sweep = `expires_at < now`, null = never); **opt-in `encrypt_data`**; Store port + in-memory test adapter; files via ActiveStorage `signed_id`.
10. **Identity/concurrency/repeatability (§4):** three orthogonal axes. **Identity** = `instance_key` digest — `concurrency_key` set → `SHA256(name | serialized(key))` (tenant always folded in, §4.4); omitted → `SHA256(name | wizard_token)` (fresh per launch, repeatable). **Concurrency** = `concurrency_key { … }` (Solid Queue-style); the keyed `in_progress` row IS the lock — a second launch at the same key resumes, never forks. **Repeatability** = `one_time` (requires a `concurrency_key`): on completion RETAIN the row (blocks restart, gate-able); without it DELETE the row (repeatable; tokened runs always are). `wizard_token` (URL `:token` segment for authenticated runs; the Rails session for guest `anonymous` runs — minted if absent) is the tokened/pre-auth principal, available in `concurrency_key`; pre-auth→auth stamps `owner` without rekeying. Gate = `ensure_wizard_completed` recomputes the same `instance_key` and checks `completed?(instance_key:)`; only one-time wizards are gateable. (Replaces the earlier `once_per`/`one_time once_per:` model.)
11. **Migrations:** gem-shipped (kept over copy-generator), per-feature subdirs, Railtie appends enabled paths **after `:load_config_initializers`** (timing fix), targeting `config.wizards.database` (multi-db aware); `schema.rb` round-trips so `db:schema:load`/CI work normally. Namespaced `config.wizards.enabled = true` (false default), `.cleanup_after`, `.database`.
12. **No generator in v1.**
13. **Defaults:** `instance_key` is either `SHA256("concurrency|#{wizard}|#{serialized(concurrency_key)}")` (keyed; tenant folded into the serialized key) or `SHA256("tokened|#{wizard}|#{wizard_token}")` (no `concurrency_key`). Owner is **never** in the digest — keyed runs are identified by the `concurrency_key`, tokened runs by the `wizard_token` — so pre-auth→auth never rekeys; login just stamps `owner` onto the row. `status` ∈ `in_progress | completing | completed` (`completing` is the transient lock-guard state for concurrent-submit protection §6.2; sweep hard-deletes idle `in_progress`, no `abandoned`); one-time completion markers kept **forever**; the per-run `token` is carried in the **Rails session** for guest (`anonymous`) runs (namespaced per wizard, no TTL — the row's `cleanup_after` is the lifetime, auto-cleared by Rodauth's `reset_session` on login/logout) and in the **URL `:token` segment** for authenticated repeatable runs, cleared on completion.
14. **Error handling:** `on_submit`/`execute` **must use bang methods** (`create!`/`update!`) — failure is signaled by a raised exception, not a return value (non-bang `false` would advance silently). Engine catches `ActiveRecord::RecordInvalid` (→ field errors), `Plutonium::Wizard::StepError` (→ base error, for non-AR failures), re-raises other `StandardError`. `execute` may also `failed(...)`. (§6.1)
