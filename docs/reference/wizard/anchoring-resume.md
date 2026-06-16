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
    on_submit { anchor.update!(logo: data.logo) }   # mutate the anchor
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
    anchor.update!(archived_at: Time.current, archive_reason: data.reason)
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
- **`wizard_token`** (URL param ?? signed cookie, minted if absent) is the **per-run id** for runs with no `concurrency_key` — a fresh, unguessable token per launch makes each run distinct and repeatable. It is **not** a pre-auth principal that survives login: authenticated runs are guarded by [owner-scoping](#authentication), and a wizard never crosses the auth boundary mid-flow.

The owner, anchor, and scope are also stored as plain polymorphic columns (`owner_type`/`owner_id`, etc.) for listing and querying — but identity is the digest.

## Resume

A `concurrency_key`-keyed wizard's `in_progress` row **is the lock**: a second launch at the same key resumes it instead of forking. Look up the row by `instance_key`; if one exists, the user continues where they left off. A tokened (no `concurrency_key`) wizard resumes via its run-id cookie within the same session, and starts a fresh run otherwise.

For a non-`anonymous` (authenticated) wizard, **every resume is owner-scoped**: a row may only be resumed by the user that owns it. A run id leaked in a URL can't be picked up by another logged-in user — the engine treats a foreign row as not-found (404). See [Authentication](#authentication).

On resume the engine:

- Restores the step cursor and `data` (typed snapshot rehydrated from the JSON column).
- Re-renders the current step's form seeded from staged `data` — including repeater rows (a `structured_input ..., repeat:` step re-renders the right number of filled rows, not one blank row).
- Rehydrates `persisted[:key]` from stored GlobalIDs, so a per-step `on_submit` create flow returning later still sees records made by earlier steps.

Navigation never loses data: **Back** moves the cursor without validating and never discards `data`; branch-hidden steps' data is kept in the store and only pruned (on a working copy) at finalize.

## Authentication

**Wizards require authentication by default.** Entry without a `current_user` is rejected (redirect to login / 401). A wizard never crosses the auth boundary mid-flow.

- **Default (authenticated).** `current_user` is required throughout. Every session lookup/resume is **owner-scoped** (`where(owner: current_user)` + an owner check), so a run id leaked in a URL can't be resumed by another logged-in user.
- **`anonymous` (guest).** Opt in with the `anonymous` macro. The wizard may run with no `current_user`; its identity is the server-minted, unguessable `wizard_token` (httponly, `secure`, `same_site: :lax`, short-TTL cookie, cleared on completion). It guards only the user's own in-progress data. Its terminal `execute` **may** authenticate (e.g. a signup flow that creates the account and logs in) — that login goes through Rodauth, which rotates the Rails session. There is **no** mid-flow owner-stamping, token-survives-login, or instance_key rekey.

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
    account = Account.create!(email: data.email)
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
