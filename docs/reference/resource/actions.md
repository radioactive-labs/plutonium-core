# Actions

Custom buttons that go beyond standard CRUD — publish, archive, import, send invitation, etc. Two flavors:

- **Simple actions** — navigate to an existing URL.
- **Interactive actions** — run an [Interaction](/reference/behavior/interactions), optionally collecting input via a modal form.

## 🚨 Critical

- **Every custom action needs a policy method.** `action :publish` requires `def publish?` on the policy. Undefined methods return `false`, so the action silently disappears.
- **For interactive actions, visibility is inferred from the interaction's attributes.** Don't declare `record_action: true` / `bulk_action: true` etc. by hand unless you're opting OUT.
- **Bulk action authorization is per-record.** If any selected record fails the policy check, the entire request is rejected.
- **Always pass `as:`** on custom routes — without it, `resource_url_for` can't generate URLs (critical for nested resources).
- **Prefer interactive actions over hand-written controller routes.** Anything with business logic belongs in an interaction.

## Action visibility flags

| Flag | Where the button appears |
|---|---|
| `resource_action: true` | Index page (top toolbar) — for actions that operate on the collection (Import, Export, Create) |
| `record_action: true` | Show page — for actions on a single record (Edit, Archive, Delete) |
| `collection_record_action: true` | Per-row in the index table — for quick actions (Edit, Show) |
| `bulk_action: true` | Bulk-actions toolbar (shown when records are selected) |

### Inferred visibility (interactive actions)

For `interaction:`-based actions, all four flags are **inferred from the interaction's attributes** — don't declare them by hand:

| Interaction declares | Inferred flags |
|---|---|
| `attribute :resource` | `record_action: true` + `collection_record_action: true` |
| `attribute :resources` (plural) | `bulk_action: true` |
| neither | `resource_action: true` |

User-supplied flags override the inferred ones, but only **opt-out** makes sense — the interaction's `attribute :resource` / `attribute :resources` already fixes its semantic shape:

```ruby
# :resource interaction → defaults to record_action + collection_record_action.
# Hide from per-row menu, keep on show page:
action :archive, interaction: ArchiveInteraction, collection_record_action: false

# Hide from show page, keep per-row button:
action :preview, interaction: PreviewInteraction, record_action: false
```

Declare the flags manually for **simple/navigation actions** (no `interaction:`) or when opting out of an inferred slot.

## Action options

```ruby
action :name,
  # Display
  label:       "Custom Label",          # default: name.titleize
  description: "What it does",
  icon:        Phlex::TablerIcons::Star,
  color:       :danger,                  # :primary, :secondary, :danger

  # Visibility (combine as needed)
  resource_action:          true,
  record_action:            true,
  collection_record_action: true,
  bulk_action:              true,

  # Conditional visibility — display-only proc, NOT authorization (see below)
  condition: -> { params[:beta] == "1" },

  # Grouping
  category: :primary,                    # :primary, :secondary, :danger
  position: 50,                          # display order (lower = first)

  # Behavior
  confirmation: "Are you sure?",
  turbo_frame:  "_top",
  return_to:    "/custom/path",
  route_options: {action: :foo},
  modal: :slideover,                     # :slideover / :centered — overrides the definition's modal mode
  size:  :lg,                            # :sm / :md / :lg / :xl / :auto / :full — overrides the definition's modal size

  # HTML attributes (see below)
  link:   {target: "_blank", rel: "noopener"},  # merged onto the action's <a> renderings
  button: {data: {analytics: "archive"}}        # merged onto the button_to <form> (non-GET)
```

### HTML attributes — `link:` / `button:`

Two per-element attribute bags, deep-merged over the framework's own attributes at render time — **the author wins on every key**, recursively through nested `data`:

- **`link:`** applies to every `<a>` rendered for the action: the toolbar link (GET), dropdown items (**any** HTTP method — dropdown items are always anchors, submitting via `data-turbo-method`), bulk-action links, kanban column action links, and the grid/kanban card's hidden show link (for `:show`).
- **`button:`** applies to the `button_to` **`<form>`** element of the non-GET toolbar rendering (the form wrapper, not the inner `<button>`).

```ruby
action :documentation,
  route_options: {url: "https://docs.example.com"},
  resource_action: true,
  link: {target: "_blank", rel: "noopener noreferrer", data: {analytics: "docs"}}
```

Because the author wins, you can override anything — `turbo_frame`, `class`, `data-*` — at your own risk. Two things to know:

- `class:` **replaces** the framework's classes (no token append) — a bare `link: {class: "mt-2"}` removes the button styling entirely.
- Pass `data:` as a **hash**. The merge only recurses when both sides are hashes, so a scalar `data:` replaces the framework's data wholesale (dropping `turbo_confirm`/`turbo_frame`).

Both bags round-trip through [`with(...)`](#deriving-variants-action-with), so `defined_actions[:edit].with(link: {target: "_blank"})` works in `customize_actions`.

### Deriving variants — `Action#with(...)`

Action records are frozen value objects. Inside `customize_actions`, derive a copy with overrides:

```ruby
def customize_actions
  defined_actions[:edit] = defined_actions[:edit].with(turbo_frame: "_top")
end
```

## Conditional visibility — `condition:`

Like the `condition:` proc on [inputs/displays/columns](/reference/resource/definition), an action can be **defined but only rendered when a runtime proc is truthy**. It's purely a toggle on whether the **button is shown** — the action (and its route) stays fully live either way.

The headline use case: **expose an action's endpoint without surfacing it in the UI** — e.g. one you call from the API, a webhook, or another service. Hide the button with an always-falsy condition; the route still works:

```ruby
# Defined and callable (API / programmatic), but no button anywhere in the UI:
action :sync_inventory, interaction: SyncInventoryInteraction, condition: -> { false }
```

It also works as a dynamic toggle driven by the **record** or the **view/request** context:

```ruby
# object → the row/shown record (record & collection-record actions):
action :reopen,  interaction: ReopenInteraction,  condition: -> { object.closed? }
# view/request state — feature flag, preview/beta mode:
action :preview, interaction: PreviewInteraction, condition: -> { params[:beta] == "1" }
```

Inside the proc, `object`/`record` is the contextual record, and every other call delegates to the **view context**:

| Available | Notes |
|---|---|
| `object` / `record` | The row/shown record for **record** and **collection-record** actions; **`nil`** for resource and bulk actions (no single record). Guard with `object&.…` if a condition is shared across action kinds. |
| `params`, `request` | Current request. |
| `current_user`, `current_parent` | The signed-in user and (nested) parent. |
| `resource_record!` | The shown record on the show page; raises on index/table — prefer `object`. |
| `allowed_to?`, `policy_for`, other helpers | The usual view helpers. |

`object` is evaluated **per row** in tables and grids, so per-record show/hide works there too.

::: danger `condition:` is NOT authorization — it only hides the button
A hidden action still has a **live route**: anyone who knows the URL can still trigger it. `condition:` decides whether the *button renders*, never whether the *request is allowed*.

```ruby
# 🚫 WRONG — this does NOT stop non-admins. The route is live; they can POST to it.
action :wipe, interaction: WipeInteraction, condition: -> { current_user.admin? }

# ✅ RIGHT — authorization belongs in the policy. The action only runs if this returns true.
class WidgetPolicy < ResourcePolicy
  def wipe? = current_user.admin?
end
```

**Rule of thumb:** "who may run this" → **policy** (`def action_name?`). "is this UI relevant right now" → `condition:`. Authorization is enforced regardless of `condition:`; the two compose — an action appears only when the policy permits **and** the condition is truthy.
:::

::: tip Per-record display vs. per-record authorization
`condition: -> { object.draft? }` is fine for **showing/hiding** a per-record button. But if the rule is about **who may run it** ("only while draft *and* nobody else has it locked"), put it in the policy — `def publish? = record.draft?` is also evaluated per record (per row), and unlike `condition:` it actually gates execution.
:::

## Simple actions (navigation)

Link to an existing route. The target route MUST exist.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # External URL
  action :documentation,
    label: "Documentation",
    route_options: {url: "https://docs.example.com"},
    icon: Phlex::TablerIcons::Book,
    resource_action: true

  # Custom controller action
  action :reports,
    route_options: {action: :reports},
    icon: Phlex::TablerIcons::ChartBar,
    resource_action: true
end
```

::: warning Custom routes need `as:`
```ruby
resources :posts do
  collection { get :reports, as: :reports }   # ← `as:` required
end
```

Without it, `resource_url_for` can't build the URL — particularly critical for nested resources.
:::

For anything with business logic, use an **interactive action** instead.

## Interactive actions

Run an [Interaction](/reference/behavior/interactions) — automatically renders a form if the interaction declares attributes beyond `:resource`/`:resources`, otherwise executes immediately with a confirmation.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  action :publish, interaction: PublishInteraction

  action :archive, interaction: ArchiveInteraction,
    color:         :danger,
    category:      :danger,
    position:      1000,
    confirmation:  "Are you sure?"
end
```

### Per-record interaction (record action)

```ruby
class ArchiveInteraction < ResourceInteraction
  presents label: "Archive",
           icon:  Phlex::TablerIcons::Archive,
           description: "Move to archive"

  attribute :resource

  def execute
    resource.archived!
    succeed(resource).with_message("Record archived.")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

Register:

```ruby
action :archive, interaction: ArchiveInteraction
# record_action + collection_record_action inferred automatically
```

### With form inputs

The interaction declares extra `attribute` and `input` lines → a modal form renders before execution.

```ruby
class InviteUserInteraction < Plutonium::Resource::Interaction
  presents label: "Invite User", icon: Phlex::TablerIcons::Mail

  attribute :resource         # the company
  attribute :email
  attribute :role

  input :email, as: :email
  input :role,  as: :select, choices: %w[admin member viewer]

  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :role,  presence: true

  def execute
    UserInvite.create!(company: resource, email: email, role: role)
    succeed(resource).with_message("Invitation sent to #{email}.")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

### Bulk action

Plural `attribute :resources` → bulk action. The index table shows checkboxes and a bulk-actions toolbar.

```ruby
class BulkArchiveInteraction < Plutonium::Resource::Interaction
  presents label: "Archive Selected", icon: Phlex::TablerIcons::Archive

  attribute :resources           # array of records

  def execute
    resources.each(&:archived!)
    succeed(resources).with_message("#{resources.size} records archived.")
  rescue => error
    failed("Bulk archive failed: #{error.message}")
  end
end
```

Register:

```ruby
action :bulk_archive, interaction: BulkArchiveInteraction
# bulk_action: true inferred from `attribute :resources`
```

Policy — checked per record; fails the whole request if ANY record is unauthorized:

```ruby
def bulk_archive?
  user.admin? || record.author == user
end
```

The UI only shows bulk actions that ALL selected records support. Records are fetched via `current_authorized_scope` — users can only select records they can access.

### Resource action (no record)

Neither `:resource` nor `:resources` → resource action (shown on the index page).

```ruby
class ImportInteraction < Plutonium::Resource::Interaction
  presents label: "Import CSV", icon: Phlex::TablerIcons::Upload

  attribute :file
  input :file, as: :file
  validates :file, presence: true

  def execute
    succeed(nil).with_message("Import completed.")
  end
end
```

```ruby
action :import, interaction: ImportInteraction
```

## Immediate vs form

| Interaction shape | Behavior |
|---|---|
| Only `:resource` / `:resources` (no extra inputs) | **Immediate** — browser confirmation (`"#{label}?"`, e.g. `"Archive?"`), then runs. Override with `confirmation: "Custom"` or `confirmation: false`. |
| Additional `attribute` / `input` declared | **Form** — renders the action's form in a modal first; no auto-confirmation (the form is the confirmation). |

## Built-in CRUD actions

These are defined by default on every definition:

```ruby
action :new,
  route_options: {action: :new},
  resource_action: true,
  category: :primary,
  icon: Phlex::TablerIcons::Plus,
  position: 10

action :show,
  route_options: {action: :show},
  collection_record_action: true,
  icon: Phlex::TablerIcons::Eye,
  position: 10

action :edit,
  route_options: {action: :edit},
  record_action: true,
  collection_record_action: true,
  icon: Phlex::TablerIcons::Edit,
  position: 20

action :destroy,
  route_options: {method: :delete},
  record_action: true,
  collection_record_action: true,
  category: :danger,
  icon: Phlex::TablerIcons::Trash,
  position: 100,
  confirmation: "Are you sure?",
  turbo_frame: "_top"
```

### Customizing built-ins

Re-declare with the options you want changed:

```ruby
class PostDefinition < ResourceDefinition
  action :destroy,
    confirmation: "This will permanently delete the post and all comments.",
    route_options: {method: :delete},
    record_action: true,
    collection_record_action: true,
    category: :danger,
    icon: Phlex::TablerIcons::Trash,
    position: 100,
    turbo_frame: "_top"
end
```

> **CSV export is not an action.** It's a built-in, policy-gated capability with its own
> button — see [CSV Export](./export.md). Don't declare it with `action :export_csv`.

## Interaction responses

```ruby
def execute
  # Success — redirects to resource automatically
  succeed(resource).with_message("Done!")

  # Different redirect destination
  succeed(resource)
    .with_redirect_response(custom_dashboard_path)
    .with_message("Redirecting...")

  # Failures
  failed(resource.errors)
  failed("Something went wrong")
  failed("Invalid value", :email)         # attaches error to a specific attribute
  failed(email: "is invalid", name: "is required")   # hash form
end
```

::: tip Automatic redirect on success
You only need `with_redirect_response` for a non-default destination. The controller redirects to the resource (show page) by default.
:::

## Route options

```ruby
# Simple route to controller action
action :preview,
  route_options: {action: :preview},
  record_action: true

# Custom HTTP method
action :archive,
  route_options: {method: :post, action: :archive},
  record_action: true

# External URL
action :docs,
  route_options: {url: "https://docs.example.com"},
  resource_action: true

# Custom URL resolver
action :create_deployment,
  route_options: Plutonium::Action::RouteOptions.new(
    url_resolver: ->(subject) {
      resource_url_for(Deployment, action: :new, parent: subject)
    }
  ),
  record_action: true
```

## Inherited actions

Actions defined on the base `ResourceDefinition` are inherited by every resource:

```ruby
# app/definitions/resource_definition.rb
class ResourceDefinition < Plutonium::Resource::Definition
  action :archive, interaction: ArchiveInteraction, color: :danger, position: 1000
end

# All resources inherit :archive automatically
class PostDefinition < ResourceDefinition
end
```

## Portal-specific actions

```ruby
class AdminPortal::PostDefinition < ::PostDefinition
  action :feature,       interaction: FeaturePostInteraction
  action :bulk_publish,  interaction: BulkPublishInteraction
end
```

## Authorization

The policy method name matches the action name plus `?`:

```ruby
class PostPolicy < ResourcePolicy
  def publish? = user.admin? || record.author == user
  def archive? = user.admin?
  def import?  = create?
end
```

Undefined → action returns `false` → button doesn't appear. See [Behavior › Policy](/reference/behavior/policies) for the full policy surface.

## Common patterns

### Archive / restore

```ruby
action :archive,
  interaction: ArchiveInteraction,
  color: :danger

action :restore,
  interaction: RestoreInteraction
```

### Export

```ruby
action :export,
  interaction: ExportInteraction,
  icon: Phlex::TablerIcons::Download
```

## Related

- [Definition](./definition) — fields, page chrome
- [Query](./query) — search, filters, scopes
- [Behavior › Interactions](/reference/behavior/interactions) — writing interaction classes
- [Behavior › Policy](/reference/behavior/policies) — authorizing custom actions
