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

- **Record action** (`wizard :configure, ...` on a definition for an anchored wizard) — auto-mounted as a **member route** (`/companies/:id/wizards/configure/:step`) on the resource controller. The anchor is resolved through that controller's scoped, policy-gated `resource_record!` — never an unscoped `find_by`, so a record outside the portal's authorized scope (or a non-existent id) 404s instead of leaking another tenant's record.
- **Collection action / create flow** — no anchor.

::: tip Anchored member routes are IDOR-safe by construction
Because the anchor comes from `resource_record!` (the same scoped lookup CRUD and interactive record actions use), an anchored wizard can only ever operate on a record the current user is authorized to see in this portal. For `once_per: :anchor` gating on a **portal-level** wizard, the host must still supply the anchor via `wizard_gate_anchor` (see [One-time wizards](/reference/wizard/one-time#once-per-anchor)).
:::

## Instance identity

Every running wizard has a deterministic **instance key** — a digest the session row is uniquely keyed by. It is derived from the wizard class, the portal scoping entity, the anchor, and the identity principal:

```
instance_key = SHA256("#{wizard}|#{scope_gid}|#{anchor_gid}|#{token.presence || owner_gid}")
```

- **`scope_gid`** — the current portal scoping entity (the tenant), when the portal is entity-scoped; blank otherwise. Folding it in means the same user running the same non-anchored wizard in two different tenant portals gets two distinct rows rather than colliding.
- **`anchor_gid`** — the anchor's GlobalID, for anchored wizards.
- **principal** — `token` if present, else the owner (user) GID.

The owner, anchor, and scope are also stored as plain polymorphic columns (`owner_type`/`owner_id`, etc.) for listing and querying — but identity is the digest, so nullable components can't spawn duplicate singletons.

## Resume

The default policy is a **singleton per `(user, wizard)`**. Look up the `in_progress` row by `instance_key`; if one exists, the user continues where they left off.

On resume the engine:

- Restores the step cursor and `data` (typed snapshot rehydrated from the JSON column).
- Re-renders the current step's form seeded from staged `data` — including repeater rows (a `structured_input ..., repeat:` step re-renders the right number of filled rows, not one blank row).
- Rehydrates `persisted[:key]` from stored GlobalIDs, so a per-step `on_submit` create flow returning later still sees records made by earlier steps.

Navigation never loses data: **Back** moves the cursor without validating and never discards `data`; branch-hidden steps' data is kept in the store and only pruned (on a working copy) at finalize.

## Related

- [DSL reference](/reference/wizard/dsl) — `anchored`, `anchor`, `persisted`.
- [Storage & config](/reference/wizard/storage-config) — the session table + columns.
- [One-time wizards](/reference/wizard/one-time) — durable completion + the gate.
