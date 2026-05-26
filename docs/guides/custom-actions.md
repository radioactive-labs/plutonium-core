# Custom Actions

Add buttons beyond CRUD — Publish, Archive, Import, Send invitation, Bulk-update, etc.

## Goal

A button appears in the right place (show page / table row / index header / bulk-actions toolbar), the user clicks it, optional form collects input, business logic runs, a success/failure message appears.

## Two flavors

| Flavor | Use for |
|---|---|
| **Simple action** — navigate to a URL | Linking to external docs, jumping to a custom page that does its own thing |
| **Interactive action** — run an interaction class | Anything with business logic (the common case) |

Prefer interactive actions. They handle authorization, form rendering, modal chrome, success/failure messaging, and automatic redirects — all for free.

## Quick recipe — interactive action

### 1. Write the interaction

```ruby
# app/interactions/publish_post_interaction.rb
class PublishPostInteraction < ResourceInteraction
  presents label: "Publish",
           icon:  Phlex::TablerIcons::Send,
           description: "Make this post public"

  attribute :resource

  def execute
    resource.update!(published: true, published_at: Time.current)
    succeed(resource).with_message("Post published!")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

::: warning Rescue `ActiveRecord::RecordInvalid`
Plutonium doesn't rescue it automatically. Always rescue when using `create!` / `update!` / `save!`, return `failed(e.record.errors)`.
:::

### 2. Register it in the definition

```ruby
class PostDefinition < ResourceDefinition
  action :publish, interaction: PublishPostInteraction
end
```

Action visibility (record / bulk / resource) is **inferred** from the interaction's attributes — no need to declare `record_action: true`. See [Inferred visibility](#inferred-visibility) below.

### 3. Add a policy method

```ruby
class PostPolicy < ResourcePolicy
  def publish? = update? && record.draft?
end
```

🚨 Without this, the button silently disappears (undefined methods return `false`).

### 4. Visit the show page

The "Publish" button appears in the toolbar. Clicking it shows a "Publish?" confirmation, then runs.

## Inferred visibility

For `interaction:`-based actions, visibility flags are inferred from the interaction:

| Interaction declares | Inferred flag → button shows up |
|---|---|
| `attribute :resource` | `record_action: true` + `collection_record_action: true` → show page + per-row |
| `attribute :resources` (plural) | `bulk_action: true` → bulk toolbar |
| neither | `resource_action: true` → index page header |

User-supplied flags can only **opt OUT** of inferred ones. Don't try to "broaden" — the interaction's attribute shape is semantic:

```ruby
# Hide from per-row menu, keep on show page
action :archive, interaction: ArchiveInteraction, collection_record_action: false

# Hide from show page, keep per-row only
action :preview, interaction: PreviewInteraction, record_action: false
```

For simple navigation actions (no `interaction:`), declare flags manually.

## With form inputs

If the interaction declares extra `attribute`/`input`, a modal form is rendered first:

```ruby
class Company::InviteUserInteraction < ResourceInteraction
  presents label: "Invite User", icon: Phlex::TablerIcons::Mail

  attribute :resource   # the company
  attribute :email
  attribute :role

  input :email, as: :email
  input :role,  as: :select, choices: %w[admin member]

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

## Bulk actions

Plural `attribute :resources` automatically becomes a bulk action. The table gets checkboxes and a bulk-actions toolbar.

```ruby
class BulkArchiveInteraction < ResourceInteraction
  presents label: "Archive Selected", icon: Phlex::TablerIcons::Archive

  attribute :resources

  def execute
    resources.update_all(archived: true)
    succeed(resources).with_message("Archived #{resources.size} records.")
  end
end
```

Policy — checked **per record** (fails the whole request if any record is unauthorized):

```ruby
def bulk_archive?
  create? && !record.locked?
end
```

Two related behaviors:

- A row gets a `✕` instead of a checkbox when **no** bulk action applies to it (no `*_bulk?` policy method on that record returns true).
- A bulk action only appears in the toolbar when **every selected row** supports it. Mixing one unsupported row hides the action until you deselect.

![Bulk action toolbar with selected drafts](/images/guides/custom-actions-bulk.png)

## Resource action (no specific record)

Neither `:resource` nor `:resources` → resource action on the index page:

```ruby
class ImportInteraction < ResourceInteraction
  presents label: "Import CSV", icon: Phlex::TablerIcons::Upload

  attribute :file
  input :file, as: :file
  validates :file, presence: true

  def execute
    # …import logic
    succeed(nil).with_message("Import completed.")
  end
end
```

## Immediate vs form

- **Immediate** — interaction has only `:resource` / `:resources` (no extra inputs). Browser confirmation (`"#{label}?"`, e.g. `"Archive?"`), then runs. Override with `confirmation: "Custom message"` or `confirmation: false` on the action.
- **Form** — interaction has additional `attribute` / `input`. Renders modal form first; no auto-confirmation (the form is the confirmation).

## Action options

```ruby
action :name,
  # Display
  label:       "Custom Label",
  description: "What it does",
  icon:        Phlex::TablerIcons::Star,
  color:       :danger,                  # :primary, :secondary, :danger

  # Grouping
  category: :primary,                    # :primary, :secondary, :danger
  position: 50,

  # Behavior
  confirmation: "Are you sure?",
  modal: :slideover,                     # :slideover / :centered — overrides definition's modal mode
  size:  :lg                             # :sm / :md / :lg / :xl / :auto / :full — overrides definition's modal size
```

Full options: [Reference › Resource › Actions › Action options](/reference/resource/actions#action-options).

## Simple actions (navigation only)

When you just want to link somewhere:

```ruby
action :documentation,
  label: "Docs",
  route_options: {url: "https://docs.example.com"},
  icon: Phlex::TablerIcons::Book,
  resource_action: true

action :reports,
  route_options: {action: :reports},   # links to PostsController#reports
  resource_action: true
```

Custom routes MUST be named:

```ruby
register_resource ::Post do
  collection { get :reports, as: :reports }   # ← `as:` is required
end
```

Without `as:`, `resource_url_for` can't build the URL.

## Inherited actions

Actions defined on the base `ResourceDefinition` propagate to every resource:

```ruby
# app/definitions/resource_definition.rb
class ResourceDefinition < Plutonium::Resource::Definition
  action :archive, interaction: ArchiveInteraction, color: :danger, position: 1000
end
```

Every resource gets `:archive` automatically.

## Chaining interactions

```ruby
def execute
  CreateUserInteraction.call(view_context:, **user_params)
    .and_then { |r| SendWelcomeEmail.call(view_context:, user: r.value) }
    .and_then { |r| LogActivity.call(view_context:, user: r.value) }
    .with_message("User created and welcomed!")
end
```

The chain short-circuits on the first failure.

## Common issues

- **Action button missing** — check the policy method (`def my_action?`). Undefined returns `false`.
- **`ActiveRecord::RecordInvalid` crashes the action** — not rescued automatically. Wrap with `rescue`, return `failed(e.record.errors)`.
- **Bulk action fails on some records** — that's by design. Bulk policy is checked per-record; if any fails, the whole request is rejected. Either fix authorization or pre-filter the selection.
- **Confirmation prompt shows when you don't want one** — pass `confirmation: false` on the action.

## Related

- [Reference › Resource › Actions](/reference/resource/actions) — full action options and bulk patterns
- [Reference › Behavior › Interactions](/reference/behavior/interactions) — interaction class anatomy
- [Reference › Behavior › Policies](/reference/behavior/policies) — `def <action>?` methods
- [Authorization](./authorization) — policy patterns
