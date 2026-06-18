# Anchoring & resume

How a wizard binds to an existing record (anchoring), how a running wizard is identified, and how a user resumes where they left off.

## Anchoring

An **anchored** wizard runs against an existing record — the analogue of `attribute :resource` on an interaction. The anchor is read-only context, available from any step (and `condition:`/`on_submit`/`execute`) via the `anchor` accessor.

```ruby
class ConfigureCompanyWizard < Plutonium::Wizard::Base
  anchored with: Company           # operate on a Company

  step :branding, label: "Branding" do
    attribute :logo, :string
    input :logo
    on_submit { anchor.update!(logo: data.branding.logo) }   # mutate the anchor
  end

  def execute
    anchor.update!(configured_at: Time.current)
    succeed(anchor)
  end
end
```

### Forms of `anchored`

| Declaration | Meaning |
|---|---|
| `anchored with: Company` | A single concrete type. |
| `anchored with: [Company, Organization]` | Polymorphic — accepts any listed type. |
| `anchored` (no `with:`) | Generic — the type binds at registration to whichever resource hosts it (shareable library wizard). |
| *(omit `anchored`)* | No anchor — a pure data → create flow. |

```ruby
# A generic, shareable wizard — bound to a concrete type at registration.
class ArchiveWithReasonWizard < Plutonium::Wizard::Base
  anchored

  step :reason do
    attribute :reason, :string
    input :reason, as: :textarea
    validates :reason, presence: true
  end

  def execute
    anchor.update!(archived_at: Time.current, archive_reason: data.reason.reason)
    succeed(anchor)
  end
end
```

### `anchor` raises when absent

```ruby
anchor   # => the record, for an anchored wizard
         # => raises Plutonium::Wizard::NotAnchoredError, for a non-anchored one
```

`anchor` never returns `nil`. Anchored-vs-not is a static property of the wizard, so reaching for `anchor` when the wizard isn't `anchored` is a programming error, not a runtime condition to guard.

The anchor is **not** part of `persisted` — `persisted` holds only records the wizard creates. The anchor is an input the wizard was launched against.

### Anchor resolution per surface

The wizard body never cares where the anchor came from; the launch surface resolves it:

- **Record action** (`wizard :configure, ...` on a definition for a `with:`-anchored wizard) — auto-mounted as a **member route** (`/companies/:id/wizards/configure/:step`) on the resource controller. The anchor is resolved through that controller's scoped, policy-gated `resource_record!` — never an unscoped `find_by`, so a record outside the portal's authorized scope (or a non-existent id) 404s instead of leaking another tenant's record.
- **Context anchor** (`anchored via: :method`) — mounted **portal-level** with `register_wizard`; the anchor is resolved by calling that method on the controller (e.g. `via: :current_scoped_entity` for the tenant). No URL `:id`, IDOR-safe (trusted context). An optional `with:` type-asserts the result.
- **Collection action / create flow** — no anchor.

::: tip Anchored member routes are IDOR-safe by construction
Because the anchor comes from `resource_record!` (the same scoped lookup CRUD and interactive record actions use), a `with:`-anchored wizard can only ever operate on a record the current user is authorized to see in this portal. A `via:`-anchored wizard is IDOR-safe by trusting the resolved context.
:::

## Instance identity

Every running wizard has a deterministic **instance key** — a digest the session row is uniquely keyed by. There are two recipes, by identity axis ([see Identity, concurrency & repeatability](/reference/wizard/dsl)):

```
# concurrency_key set:
instance_key = SHA256("concurrency|#{wizard}|#{serialized(concurrency_key)}")
# no concurrency_key:
instance_key = SHA256("tokened|#{wizard}|#{wizard_token}")
```

- **`concurrency_key`** is serialized records → GID, scalars → string, arrays joined — with the **tenant (`current_scoped_entity`) folded in automatically**, so the same user running the same keyed wizard in two tenant portals gets two distinct rows.
- **`wizard_token`** is the **per-run id** for runs with no `concurrency_key` — a fresh, unguessable token per launch makes each run distinct and repeatable. Its source depends on the run identity: an **authenticated** repeatable run carries it in the URL `:token` segment (guarded by [owner-scoping](#authentication)); a **guest (`anonymous`)** run keys off the **Rails session** (never the URL — no leak surface). It is **not** a pre-auth principal that survives login, and a wizard never crosses the auth boundary mid-flow.

The owner, anchor, and scope are also stored as plain polymorphic columns (`owner_type`/`owner_id`, etc.) for listing and querying — but identity is the digest.

## Resume

A `concurrency_key`-keyed wizard's `in_progress` row **is the lock**: a second launch at the same key resumes it instead of forking. Look up the row by `instance_key`; if one exists, the user continues where they left off. A tokened (no `concurrency_key`) wizard resumes via its per-run id (carried in the URL `:token` segment for an authenticated run, or the Rails session for a guest run) and starts a fresh run otherwise.

For a non-`anonymous` (authenticated) wizard, **every resume is owner-scoped**: a row may only be resumed by the user that owns it. A run id leaked in a URL can't be picked up by another logged-in user — the engine treats a foreign row as not-found (404). See [Authentication](#authentication).

### Listing in-progress wizards

`Plutonium::Wizard.in_progress_for(view_context)` (→ `Resume.entries_for(view_context)`) takes the `view_context` (as interactions do) and derives the run owner (`current_user`), tenant scope (`current_scoped_entity` when `scoped_to_entity?`, else `nil`), and **portal** from it, returning the owner's in-progress runs **for the current portal**, newest-first, each enriched with the wizard's `label`/`icon`, `current_step` (+ `current_step_label`), `updated_at`, the raw `session` row, and a resolved `resume_url`. A run is only ever listed (and linked) by the portal it was launched in: a non-scoped portal lists only unscoped runs, a scoped portal narrows to the current tenant. Two portals can share an entity scope, so the launching portal (the `engine` column) is recorded per-run because scope alone can't identify it. `resume_url` is built through the current portal's routes: `resource_url_for(record, wizard:, step:)` for a `wizard`-macro **anchored** mount, the named route (with the scope segment and, for tokened runs, the `:token`) for a `register_wizard` mount; a row that can't be resolved here (e.g. a non-anchored `wizard`-macro run) yields `resume_url: nil` plus a `resume_unresolved_reason`. There is no per-wizard query helper; filter the returned array (`select { |e| e.wizard_class == X }` or `{ |e| e.session.anchor == record }`). See the [guide](/guides/wizards#listing-in-progress-wizards).

### The implied anchored key

An `anchored` wizard with **no explicit `concurrency_key`** is keyed by default — `{ [anchor, current_user] }`, with the tenant folded in. So an anchored wizard, out of the box, is **one in-progress draft per user per record**: re-launching it for the same record resumes your draft, and two users editing the same record get **independent** runs (no collision).

This is the right default because anchoring without keying is a footgun in both directions: a *tokened* anchored wizard forks a new run on every launch, while `{ anchor }` (record-only) keys across users — so a second user editing the same record collides with the first and is owner-scoped out (a 404). The implied key threads the needle. The anchor's GlobalID is already globally unique (and pins the tenant for a tenant-scoped record), so `[anchor, current_user]` is the full identity; the auto-folded tenant is redundant there but load-bearing for non-anchor keys.

Override when you want different semantics:
- `concurrency_key { anchor }` — a true singleton: **one run per record, any user** ("configure this once, by anyone"). A concurrent second user is blocked (owner-scoped) until the first finishes.
- `concurrency_key { wizard_token }` — make the anchored wizard **repeatable** (a fresh run per launch).

Anonymous (guest) anchored wizards are exempt — a guest has no real user to key by, so they stay session-tokened.

### Relaunching a tokened wizard

A keyed wizard auto-resumes (its keyed row is the lock), so a bare launch always continues the single in-progress run. A **tokened** wizard has no such single run — each bare launch could mint a fresh one. By default it doesn't silently fork: it prompts. Opt out for flows that should always start clean:

```ruby
on_relaunch :new
```

With the default (`on_relaunch :prompt`), a bare launch (e.g. `GET /onboarding`) checks the user's pending runs (owner- and tenant-scoped, via the same listing as above). If any exist, it renders a **"resume or start new" page** (each pending run with a Resume link, plus a **Start new** button) instead of silently discarding that in-progress work. With no pending runs it starts fresh as usual, and **Start new** (the bare launch URL with `?new=1`) always forces a fresh run. Because the chooser only appears when a pending run exists, `:prompt` is a safe superset of `:new`. Use `on_relaunch :new` to opt out (always fork a fresh run) for flows meant to be run repeatedly from scratch.

This only applies to authenticated tokened wizards: keyed wizards already auto-resume, and `anonymous` (guest) runs are session-keyed to a single run — `on_relaunch` is a no-op for both.

On resume the engine:

- Restores the step cursor and `data` (typed snapshot rehydrated from the JSON column).
- Re-renders the current step's form seeded from staged `data` — including repeater rows (a `structured_input ..., repeat:` step re-renders the right number of filled rows, not one blank row).
- Lazily rehydrates `persisted[:key]` from stored GlobalIDs on first access (memoized per request), so a per-step `on_submit` create flow returning later still sees records made by earlier steps — without paying a `GlobalID.locate` on requests that never read `persisted`.

Navigation never loses data: **Back** moves the cursor without validating and never discards `data`. A step whose answer is later **un-chosen** (its `condition:` flips false) leaves the visible path and is **fully pruned**: its staged `data` is dropped, and if its `on_submit` had **persisted records** (save-as-you-go) those records are **rolled back**: its `on_rollback` runs first if declared (additive side-effect cleanup), then the engine **always** destroys them, so nothing is orphaned. The step's `persisted` / `data` / `visited` state is cleared, so re-entering that branch re-runs its `on_submit` from scratch. Pruning fires as soon as the branch is hidden (during the advance that flips it) and again as a safety net at finalize.

## Authentication

**Wizards require authentication by default.** Entry without a `current_user` is rejected (redirect to login / 401). A wizard never crosses the auth boundary mid-flow.

- **Default (authenticated).** `current_user` is required throughout. Every session lookup/resume is **owner-scoped** (`where(owner: current_user)` + an owner check), so a run id leaked in a URL can't be resumed by another logged-in user. `current_user` comes from the host: a portal mount inherits the portal's auth concern, while an **authenticated main-app** mount requires an app-defined `::WizardsController` carrying the auth concern (see [the override hook](/reference/wizard/registration-launch#hosting-the-controller-override-hook)).
- **`anonymous` (guest).** Opt in with the `anonymous` macro. The wizard may run with no `current_user`; its identity is the server-minted, unguessable `wizard_token` held in the **Rails session** (`session["plutonium_wizards"][<wizard_key>]`): **not a cookie, no TTL** (the row's `cleanup_after` → sweep is the authoritative lifetime; the session id is just a pointer). Session storage gives browser-close ephemerality, **auto-clear on login/logout** (Rodauth's `clear_session` → `reset_session`), and clearing on completion; the id never appears in a URL. It guards only the user's own in-progress data. Its terminal `execute` **may** authenticate (e.g. a signup flow that creates the account and logs in); that login goes through Rodauth, which rotates the Rails session. There is **no** mid-flow owner-stamping, token-survives-login, or instance_key rekey.

```ruby
class GuestSignupWizard < Plutonium::Wizard::Base
  anonymous                       # may run pre-login

  step :account do
    attribute :email, :string
    input :email, as: :email
    validates :email, presence: true
  end
  review label: "Review"

  def execute                     # the ONE boundary a guest wizard may cross
    account = Account.create!(email: data.account.email)
    # sign the account in here (the host calls Rodauth) — no special framework handling
    succeed(account)
  end
end
```

An `anonymous` wizard must be [mounted on a public route](/reference/wizard/registration-launch#public-mount-for-anonymous-wizards).

## Related

- [DSL reference](/reference/wizard/dsl) — `anchored`, `anchor`, `persisted`.
- [Storage & config](/reference/wizard/storage-config) — the session table + columns.
- [One-time wizards](/reference/wizard/one-time) — durable completion + the gate.
