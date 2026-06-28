---
name: plutonium-behavior
description: Use BEFORE writing or overriding a Plutonium controller, policy, or interaction class. Covers controller hooks, policy methods, permitted attributes, relation_scope, interaction structure, outcomes, and chaining. The single source for "how does this resource actually do things".
---

# Plutonium Behavior — Controllers, Policies, Interactions

The behavior layer is intentionally thin: **controllers route**, **policies authorize**, **interactions act**. Registering an action and rendering it lives in [[plutonium-resource]] — this skill covers how to *write* the controller hook, policy method, or interaction class behind it.

For tenant-scoped `relation_scope` and entity scoping, load [[plutonium-tenancy]].

## 🚨 Critical (read first)

- **Use generators.** `pu:res:scaffold` creates the base trio (controller/policy/interaction-base); `pu:res:conn` creates portal-specific versions. Never hand-write them.
- **Don't override CRUD actions.** Use hooks (`resource_params`, `redirect_url_after_submit`, presentation hooks). Overriding `create`/`update` usually breaks authorization, params filtering, or both.
- **`create?` and `read?` default to `false`.** Always override them explicitly. Derived methods (`update?`, `show?`, etc.) inherit automatically.
- **`permitted_attributes_for_*` must be explicit in production.** Dev auto-detection works; production raises.
- **`ActiveRecord::RecordInvalid` is NOT rescued automatically in interactions.** Always rescue when using `create!` / `update!` / `save!`, return `failed(e.record.errors)`.
- **Return `succeed(...)` or `failed(...)`** from `execute` — the controller can't tell what happened otherwise.
- **Redirect is automatic on success** — only use `with_redirect_response` for a *different* destination.
- **`relation_scope` must end up calling `default_relation_scope(relation)` somewhere in the chain.** Prefer calling it explicitly. `super` works when extending a parent policy (e.g., a package base) that itself calls it. See [[plutonium-tenancy]].
- **For `has_cents` fields, use the virtual name (`:price`), not `:price_cents`** in `permitted_attributes_for_*`.
- **Custom action ⇒ policy method.** `action :publish` needs `def publish?` on the policy (undefined methods return `false`).
- **Named custom routes.** When adding custom routes, always pass `as:` so `resource_url_for` can build URLs.

---

## 🛑 Before you write behavior: place it in the right layer (ASK — don't infer)

"Make X happen" doesn't say **where** X lives. Put it in the wrong layer and you get authorization that doesn't authorize, a 500 on the happy path, or a CRUD override that breaks params/auth. First place the requirement, then confirm names against the real code (next section):

| The requirement (in plain words) | Goes in | **NOT** in |
|---|---|---|
| "only \<role/owner\> may do X" — *who is allowed* | **Policy** `def x?` | a `condition:` proc — that only hides the button; the route stays live and callable |
| "doing X changes state / sends mail / charges a card" — *the work* | **Interaction** `execute`, registered as an action | a hand-written controller action; an override of `create`/`update` |
| "after create/update go to Y" · "munge a param" · "reshape the index query" | **Controller hook** (`redirect_url_after_submit`, `resource_params`, `filtered_resource_collection`) | overriding `create`/`update`/`index` |
| "which fields are visible / editable" | **Policy** `permitted_attributes_for_*` | the definition — that only controls *how* a field renders |

Then resolve the specifics:

1. **A custom action needs BOTH:** an interaction (the work) **and** a policy `def <action>?` (the authorization). Miss the policy method ⇒ the action silently returns `false` (dead button). Put the role check in `condition:` ⇒ it isn't enforced — a direct POST still runs.
2. **`create?`/`read?` default to `false`** — override explicitly; derived methods (`update?`/`show?`/…) inherit.
3. **Any `create!`/`update!`/`save!` in `execute`** ⇒ rescue `ActiveRecord::RecordInvalid` → `failed(e.record.errors)`. Not auto-rescued — otherwise a validation failure 500s.
4. **`has_cents`** ⇒ permit `:price`, never `:price_cents`.
5. **New vs editing** — never re-scaffold a controller/policy/interaction that's been customized.

**Never ship a guessed role method, column, enum value, or association as applied code.** `user.finance?`, `record.status_approved?`, `expense.submitted_by` either exist in the app or they don't — confirm them before writing, don't assume. Fall back to `AskUserQuestion` only for genuine product choices (what the rule *should* be), never for facts you can read.

## ✅ Before you edit: verify the ground truth (CHECK — read it, don't ask for it)

You have file access — **inspect**; don't ask the user to describe their own app.

| Check | How | Why it matters |
|---|---|---|
| File already customized | Read `app/policies/<x>_policy.rb`, the controller, `app/interactions/*` | Edit incrementally — re-scaffolding clobbers customizations |
| The role/method you authorize on exists | grep the user model for `def finance?` / `enum :role` / `has_role?` | `user.finance?` 500s (or is silently `false`) if absent |
| The columns/enum your interaction writes | Read the model + `db/schema.rb` for the enum value, `approved_by`/`approved_at`, the submitter assoc | `update!(status: :approved)` raises if the value/column is missing |
| Action not already wired | grep the definition for `action :<x>`; grep the policy for `def <x>?` | Avoids duplicate or dead actions |
| Cross-resource access | Use `authorized_resource_scope` / `allowed_to?`, never raw `where`/`find` | Raw queries bypass the other resource's tenancy + visibility |

Inspect with your own tools **before** proposing code.

## 🛠 Use the generator — and know what's hand-authored

| Task | How | Verify first |
|---|---|---|
| Base trio (controller + policy + interaction-base) | `pu:res:scaffold` | New resource |
| Portal-specific controller/policy | `pu:res:conn … --dest=portal` | Resource exists |
| **A custom-action interaction** | **Hand-author** in `app/interactions/<name>_interaction.rb` (subclass `ResourceInteraction`) — **there is NO `pu:res:interaction` generator; don't invent one** | — |
| Edit an existing customized policy/controller/interaction | Hand-edit the file | It was already generated — re-scaffolding clobbers it |

---

# Part 1 — Controllers

Plutonium controllers ship full CRUD out of the box; nearly all customization lives in definitions / policies / interactions. The controller stays thin.

## Base classes

```ruby
# app/controllers/resource_controller.rb (installed once)
class ResourceController < ApplicationController
  include Plutonium::Resource::Controller
end

# app/controllers/posts_controller.rb (per resource, generated by pu:res:scaffold)
class PostsController < ::ResourceController
  # Empty — all CRUD inherited
end
```

## What you get for free

| Action | Route | Purpose |
|--------|-------|---------|
| `index` | GET `/posts` | List with pagination, search, filters, sorting |
| `show` | GET `/posts/:id` | Display single record |
| `new` | GET `/posts/new` | Form |
| `create` | POST `/posts` | Create |
| `edit` | GET `/posts/:id/edit` | Form |
| `update` | PATCH `/posts/:id` | Update |
| `destroy` | DELETE `/posts/:id` | Delete |

Plus interactive-action routes for every action declared in the definition.

## Where customization belongs

| Concern | Lives in |
|---|---|
| Field rendering (inputs, displays, columns) | Definition |
| Search, filters, scopes, sorting | Definition |
| Custom operations (publish, archive, import) | Interaction (+ action in definition) |
| Authorization rules | Policy |
| Form/show/page chrome | Definition (custom page classes) |
| **Custom redirect logic** | **Controller hook** |
| **Param munging** | **Controller hook** |
| **Custom index query shape** | **Controller hook** |
| **Presentation of parent/entity fields** | **Controller hook** |

## Override hooks

All hooks are private methods. Override only the ones you need.

### Redirect hooks

```ruby
class PostsController < ::ResourceController
  private

  # Where to go after create/update: "show" (default), "edit", "new", "index"
  def preferred_action_after_submit = "edit"

  # Custom URL after create/update (overrides preferred_action_after_submit)
  def redirect_url_after_submit = posts_path

  # Custom URL after destroy
  def redirect_url_after_destroy = posts_path
end
```

### Parameter hook

```ruby
def resource_params
  params = super
  params[:tags] = params[:tags].split(",") if params[:tags].is_a?(String)
  params
end
```

### Index query hook

```ruby
def filtered_resource_collection
  base = current_authorized_scope
  base = base.featured if params[:featured]
  current_query_object.apply(base, raw_resource_query_params)
end
```

### Presentation hooks

Control whether parent / scoped-entity fields appear in forms and displays. Defaults are `false` (hidden, since they're inferred from the URL/portal).

```ruby
def present_parent?         = true   # show parent field on displays
def submit_parent?          = true   # include parent field in forms (default: tracks present_parent?)
def present_scoped_entity?  = true
def submit_scoped_entity?   = true
```

## Custom actions

Prefer **interactive actions** (definition + interaction) for anything with business logic. The only reason to hand-write a controller action is unusual flows (custom response shapes, external service callbacks, etc.).

```ruby
class PostsController < ::ResourceController
  def publish
    authorize_current!(resource_record!, to: :publish?)
    resource_record!.update!(published: true)
    redirect_to resource_url_for(resource_record!), notice: "Published!"
  end
end
```

Route must be named:

```ruby
resources :posts do
  member { post :publish, as: :publish }   # `as:` required!
end
```

## Key methods

### Resource access

```ruby
resource_class            # The model class
resource_record!          # Current record (raises if not found)
resource_record?          # Current record (nil if not found)
resource_params           # Permitted params for create/update
current_parent            # Parent record for nested routes
current_scoped_entity     # Tenant entity for the current portal (nil if not scoped)
```

### Authorization

**Current resource:**

```ruby
authorize_current!(record, to: :action?)  # Check permission
current_policy
permitted_attributes
current_authorized_scope                  # Scoped records the user can access
```

**Other resources** (cross-resource auth — use these, not raw `where` / `find`):

```ruby
authorize! other_record, to: :show?       # ActionPolicy — raises if denied
allowed_to?(:show?, other_record)         # Boolean check
policy_for(OtherModel)                    # Policy instance for class or record
policy_for(other_record).show?

authorized_resource_scope(OtherModel)              # Scope on the model class
authorized_resource_scope(OtherModel, relation: OtherModel.published)  # On a relation
authorized_resource_scope(OtherModel, type: :create)                   # Different action
```

`authorized_resource_scope` applies the *other* resource's `relation_scope` AND the current policy context (entity scope, etc.). **Always prefer it over `OtherModel.all` / raw `where` in cross-resource controller code** — otherwise you bypass that resource's tenancy and visibility rules.

### Definition access

```ruby
current_definition
```

### UI builders (rarely needed in controllers)

```ruby
build_form
build_detail
build_collection
```

### URL generation

```ruby
resource_url_for(@post)                          # show URL
resource_url_for(@post, action: :edit)           # edit URL
resource_url_for(Post)                           # index URL

# Nested
resource_url_for(@comment, parent: @post)
resource_url_for(Comment, action: :new, parent: @post)

# Cross-package
resource_url_for(@post, package: AdminPortal)

# Interactive actions (see Part 3 below)
resource_url_for(@post, interaction: :publish)
resource_url_for(Post, interaction: :archive, ids: [1, 2, 3])
```

## Nested resources

Routes prefixed with `nested_` automatically resolve the parent:

```ruby
# Route: /users/:user_id/nested_posts/:id
class PostsController < ::ResourceController
  # current_parent              => User instance
  # current_nested_association  => :posts
  # resource_record!            => Post scoped to that User
end
```

| Method | Returns |
|---|---|
| `current_parent` | Parent record |
| `current_nested_association` | `:posts` |
| `parent_route_param` | `:user_id` |
| `parent_input_param` | `:user` |

Parent fields are excluded from forms/displays by default — toggle with the presentation hooks above. For `has_one` associations, routes are singular (no `:id`); index redirects to show (or new if no record exists). See [[plutonium-tenancy]] for the full nested-routing story.

## Entity scoping (multi-tenancy)

When a portal calls `scope_to_entity SomeModel`, every controller in that portal automatically:

- Scopes queries to the entity
- Excludes the entity field from forms (detected by association class)
- Injects the entity on create/update
- Exposes `current_scoped_entity`

Plutonium auto-detects which `belongs_to` association points to the scoped class, even when `param_key` differs from the association name. If a model has **multiple associations to the same scoped class**, you get a runtime error and must override:

```ruby
class MatchesController < ::ResourceController
  private
  def scoped_entity_association = :home_team
end
```

For the full mechanics, load [[plutonium-tenancy]].

## Authorization verification

After-action callbacks ensure auth was performed:

```ruby
verify_authorize_current         # all actions
verify_current_authorized_scope  # all except new/create
```

Skip only when handling auth manually. Two forms:

```ruby
# Class-level — skip across multiple actions
class PostsController < ::ResourceController
  skip_verify_authorize_current only: [:custom_action]
  skip_verify_current_authorized_scope only: [:custom_action]

  def custom_action
    # do auth manually
  end
end

# Per-action — bang methods, call inside the action body
def custom_action
  skip_verify_authorize_current!
  skip_verify_current_authorized_scope!
  # do auth manually
end
```

Prefer the per-action bang form when only one action skips — keeps the exception co-located with the code that needs it.

## Portal-specific controllers

Portal controllers inherit from the feature-package controller if one exists (and include the portal's `Concerns::Controller`); otherwise from the portal's `ResourceController`.

```ruby
# Feature package controller exists
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller
end

# No feature package — inherits portal base
class AdminPortal::PostsController < AdminPortal::ResourceController
end
```

Non-resource portal pages (dashboard, settings) inherit from `PlutoniumController`:

```ruby
module AdminPortal
  class DashboardController < PlutoniumController
    def index; end
  end
end
```

---

# Part 2 — Policies

Built on [ActionPolicy](https://actionpolicy.evilmartians.io/). Plutonium adds:

- Attribute permissions (`permitted_attributes_for_*`)
- Association permissions (`permitted_associations`)
- Automatic entity scoping
- Derived action methods (`update?` inherits from `create?`, etc.)

## Base class

```ruby
# app/policies/resource_policy.rb (installed once)
class ResourcePolicy < Plutonium::Resource::Policy
  # App-wide defaults
end

# app/policies/post_policy.rb (per resource, generated)
class PostPolicy < ResourcePolicy
  def create? = user.present?
  def read?   = true

  def permitted_attributes_for_create
    %i[title content]
  end

  def permitted_attributes_for_read
    %i[title content author created_at]
  end
end
```

## Action permissions

### Must override

```ruby
def create?  # default: false
  user.present?
end

def read?    # default: false
  true
end
```

### Derived (inherit automatically)

| Method | Inherits from | Override when |
|--------|---------------|---------------|
| `update?` | `create?` | Different update rules |
| `destroy?` | `create?` | Different delete rules |
| `index?` | `read?` | Custom listing rules |
| `show?` | `read?` | Record-specific read rules |
| `new?` | `create?` | Rarely needed |
| `edit?` | `update?` | Rarely needed |
| `search?` | `index?` | Search-specific rules |
| `typeahead?` | `index?` | Autocomplete-specific rules |

`export_csv?` is the exception — it defaults to `false` (not derived) so CSV export is strictly opt-in. Override it to `true` (or `index?`) to enable the built-in export. The exported column set is `permitted_attributes_for_export` (defaults to `permitted_attributes_for_index`). See [[plutonium-resource]] → CSV Export.

### Custom actions

Define `def <action>?` matching the definition's `action :<action>`. Undefined methods return `false`:

```ruby
def publish? = update? && record.draft?
def archive? = create? && !record.archived?
def invite_user? = user.admin?
```

### Bulk actions — per-record auth

```ruby
def bulk_archive?
  create? && !record.locked?    # checked per record in the selection
end
```

How it works:

- Policy is checked **per record** in the selected set.
- **Backend:** if any record fails, the entire request is rejected.
- **UI:** only actions ALL selected records support are shown (intersection).
- Records come from `current_authorized_scope` — users can only select what they're allowed to access.

## Attribute permissions

```ruby
# Must override for production
def permitted_attributes_for_read
  %i[title content author published_at created_at]
end

def permitted_attributes_for_create
  %i[title content]
end
```

### Derived

| Method | Inherits from |
|---|---|
| `permitted_attributes_for_update` | `permitted_attributes_for_create` |
| `permitted_attributes_for_index` | `permitted_attributes_for_read` |
| `permitted_attributes_for_show` | `permitted_attributes_for_read` |
| `permitted_attributes_for_new` | `permitted_attributes_for_create` |
| `permitted_attributes_for_edit` | `permitted_attributes_for_update` |
| `permitted_attributes_for_export` | `permitted_attributes_for_index` (CSV export columns; primary key is always prepended) |

### Per-action override

```ruby
def permitted_attributes_for_index
  %i[title author created_at]                # minimal for the table
end

def permitted_attributes_for_read
  %i[title content author tags created_at]   # fuller for the show page
end
```

🚨 **Index has no `record`.** `permitted_attributes_for_index` is evaluated at collection level — `record` is `nil`. `permitted_attributes_for_show` (and `_for_read`) ARE evaluated per record. So if you write a record-dependent `_for_read`:

```ruby
def permitted_attributes_for_read
  attrs = %i[title content]
  attrs << :archive_reason if record.archived?   # uses record
  attrs
end
```

…you MUST also define an explicit `permitted_attributes_for_index` — otherwise inheritance kicks in, runs the `_for_read` body during the table render, and `record.archived?` blows up on `NoMethodError: undefined method 'archived?' for nil`.

```ruby
def permitted_attributes_for_index
  %i[title content]                              # no record-dependent fields
end
```

Same rule for `permitted_attributes_for_create` vs `_for_new` (new has no persisted record).

### Policy vs definition — what controls what

`permitted_attributes_for_*` controls **which fields appear** on a view. Definition `field`/`input`/`display`/`column` declarations only control **how** they render. A `field :name` in the definition does nothing unless `:name` is also in the relevant `permitted_attributes_for_*`.

Common mistake: adding a definition declaration and wondering why the field doesn't show — check the policy.

### Anti-pattern: nested-attributes hashes

```ruby
# ❌ NEVER
def permitted_attributes_for_create
  [:name, {variants_attributes: [:id, :name, :_destroy]}]
end
```

Plutonium extracts nested params via the form definition, not the policy. Hash entries get iterated as field names by the form renderer and render as literal text inputs.

```ruby
# ✅ Policy permits just the association name
def permitted_attributes_for_create
  [:name, :variants]
end
```

`nested_input :variants` in the definition handles the rest. See [[plutonium-resource]] › Nested Inputs.

## Association permissions

```ruby
def permitted_associations
  %i[comments tags author]
end
```

Declares which associations get their own **tab on the show page**. When `permitted_associations` is non-empty, the show page renders a tablist: a "Details" tab (the main field card + metadata aside) plus one tab per association — each lazy-loaded via a frame navigator panel pointing at the associated `has_many` collection, `has_one` record, or `belongs_to` target. When empty, the show page renders without tabs. If `permitted_attributes_for_show` resolves to **no fields**, the empty Details tab is omitted and the first association tab leads instead.

Each named association must:

- Exist on the model (raises `ArgumentError: unknown association ...` otherwise).
- Point to a class that's itself a registered Plutonium resource (raises `... is not a registered resource` otherwise).

This is **NOT** the same as:

- **Nested forms** — declared with `nested_input :variants` in the definition, requires `accepts_nested_attributes_for` on the model. See [[plutonium-resource]] › Nested Inputs.
- **Association fields on tables / show details** — controlled by `permitted_attributes_for_index` / `_for_show` listing the association name.

## Collection scoping (`relation_scope`)

Filter which records the user can see. **Always compose with `default_relation_scope(relation)` explicitly** — `super` is unreliable inside the block, and bypassing this triggers `verify_default_relation_scope_applied!`:

```ruby
relation_scope do |relation|
  relation = default_relation_scope(relation)
  user.admin? ? relation : relation.where(author: user)
end
```

For tenant scoping, parent scoping, `skip_default_relation_scope!`, and `associated_with` resolution: load [[plutonium-tenancy]].

## Portal-specific policies

```ruby
class PostPolicy < ResourcePolicy
  def create? = user.present?
end

# Admin: more permissive
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy
  def destroy? = true
  def permitted_attributes_for_create = %i[title content featured internal_notes]
end

# Public: read-only
class PublicPortal::PostPolicy < ::PostPolicy
  include PublicPortal::ResourcePolicy
  def create? = false
end
```

## Authorization context

```ruby
user                # current user
record              # the resource being authorized
entity_scope        # current scoped entity (multi-tenancy)
parent              # parent record for nested resources (nil otherwise)
parent_association  # association name on parent (e.g. :comments)
```

### Custom context

```ruby
# Policy
class PostPolicy < ResourcePolicy
  authorize :department, allow_nil: true

  def create? = department&.allows_posting?
end

# Controller
class PostsController < ResourceController
  authorize :department, through: :current_department

  private
  def current_department = current_user.department
end
```

## Common patterns

### Block archived records

```ruby
def update?  = !record.try(:archived?) && super
def destroy? = !record.try(:archived?) && super
```

### Owner-based

```ruby
def update?  = record.author == user || user.admin?
def destroy? = update?
```

### Role-based

```ruby
def create? = user.admin? || user.editor?

def update?
  return true if user.admin?
  user.editor? && record.author == user
end
```

### Conditional attribute access

```ruby
def permitted_attributes_for_create
  attrs = %i[title content]
  attrs += %i[featured author_id] if user.admin?
  attrs
end
```

---

# Part 3 — Interactions

Interactions encapsulate business logic into testable units. They're registered as actions in definitions (see [[plutonium-resource]] › Actions) and executed by the controller.

## Structure

```ruby
# app/interactions/resource_interaction.rb (installed once)
class ResourceInteraction < Plutonium::Resource::Interaction
end

# A real interaction
class PublishPostInteraction < ResourceInteraction
  presents label: "Publish",
           icon: Phlex::TablerIcons::Send,
           description: "Make this post public"

  attribute :resource
  attribute :publish_date, :datetime, default: -> { Time.current }

  input :publish_date

  validates :publish_date, presence: true

  private

  def execute
    resource.update!(published_at: publish_date)
    succeed(resource).with_message("Post published!")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

## Attributes

ActiveModel-style:

```ruby
attribute :resource                                # single record (record action)
attribute :resources                               # array of records (bulk action)
attribute :email, :string
attribute :count, :integer, default: 1
attribute :active, :boolean, default: -> { true }  # callable default
attribute :tags, :array
attribute :metadata, :hash
attribute :date, :datetime
```

The presence of `:resource` / `:resources` / neither determines the action type — see [[plutonium-resource]] › Action Types.

### Structured / repeating input

To collect a structured object or a repeating list of field-groups, use
`structured_input` (it declares the backing attribute for you):

```ruby
structured_input :address do |f|          # single → execute sees { street:, city: }
  f.input :street
  f.input :city
end

structured_input :contacts, repeat: 3 do |f|  # repeater → [ { label:, phone: }, ... ]
  f.input :label
  f.input :phone
end
```

⚠️ **`nested_input` and `accepts_nested_attributes_for` are NOT available on
interactions** (they were model-backed). Use `structured_input` instead — it's
classless and collects plain hashes/arrays. See [[plutonium-resource]] ›
Structured Inputs for options (`repeat:`, `using:`, `fields:`).

## Inputs

Same DSL as definition `input` (load [[plutonium-resource]] for the full list of `as:` types, options, dynamic blocks, etc.):

```ruby
input :email
input :role, as: :select, choices: %w[admin user]
input :content, as: :text
```

Auto-detection rule from [[plutonium-resource]] applies here too: if the attribute type already implies the right widget, don't redeclare `as:`.

## Presentation

```ruby
presents label: "Archive Record",
         icon: Phlex::TablerIcons::Archive,
         description: "Move to archive"

# Access
MyInteraction.label
MyInteraction.icon
MyInteraction.description
```

If `action :foo, interaction: FooInteraction` doesn't override `label:`/`icon:`/etc., these `presents` values are used.

## `execute` — outcomes

`execute` MUST return a `succeed(...)` or `failed(...)` outcome. Validations run automatically before `execute`; if they fail, the interaction short-circuits to `failed()`.

### Success

```ruby
succeed(resource)                                       # auto-redirect to resource
succeed(resource).with_message("Done!")
succeed(resource).with_message("Heads up!", :alert)
succeed(resource).with_redirect_response(custom_path)   # different destination
succeed(resource).with_file_response(path, filename: "report.pdf")
```

### Failure

```ruby
failed("Something went wrong")
failed(resource.errors)
failed(email: "is invalid", name: "is required")  # hash form
failed("Invalid value", :email)                   # string + attribute
```

### Chaining

```ruby
def execute
  CreateUserInteraction.call(view_context:, **user_params)
    .and_then { |r| SendWelcomeEmail.call(view_context:, user: r.value) }
    .and_then { |r| LogActivity.call(view_context:, user: r.value) }
    .with_message("User created and welcomed!")
end
```

The chain short-circuits on the first failure.

## Validations

Standard ActiveModel — run automatically before `execute`:

```ruby
validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
validates :role, inclusion: {in: %w[admin user guest]}

validate :custom_check

private

def custom_check
  errors.add(:resource, "cannot be modified when archived") if resource.archived?
end
```

## Accessing context

```ruby
def execute
  current_user = view_context.controller.helpers.current_user
  resource.update!(updated_by: current_user)
  succeed(resource)
end
```

A shorter `current_user` helper is conventional:

```ruby
private
def current_user = view_context.controller.helpers.current_user
```

## Interaction types

| Attribute pattern | Action type | Where it shows up |
|---|---|---|
| `attribute :resource` | Record action | Show page + per-row in table |
| `attribute :resources` | Bulk action | Bulk toolbar above table |
| neither | Resource action | Index page header |

**Bulk action authorization:** per-record. See [[plutonium-resource]] › Action Types and Part 2 above.

## Generating interaction URLs

Use `resource_url_for` with the `interaction:` kwarg. Action type is inferred from the element and presence of `ids:`:

```ruby
# Record action — instance argument
resource_url_for(@post, interaction: :publish)
# => /posts/:id/record_actions/publish

# Resource action — class, no ids
resource_url_for(Post, interaction: :import)
# => /posts/resource_actions/import

# Bulk action — class + ids
resource_url_for(Post, interaction: :archive, ids: [1, 2, 3])
# => /posts/bulk_actions/archive?ids[]=1&ids[]=2&ids[]=3

# Composes with parent / entity scoping
resource_url_for(@post, parent: @user, interaction: :publish)
```

The same URL serves GET (form/confirmation) and POST (commit) — the HTTP verb routes to the right controller action. Passing both `interaction:` and `action:` raises `ArgumentError`.

## Complete example

```ruby
class Company::InviteUserInteraction < Plutonium::Resource::Interaction
  presents label: "Invite User",
           icon: Phlex::TablerIcons::UserPlus

  attribute :resource          # the company
  attribute :email, :string
  attribute :role, :string

  input :email
  input :role, as: :select, choices: -> { UserInvite.roles.keys }

  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :role,  presence: true, inclusion: {in: UserInvite.roles.keys}
  validate :not_already_invited

  private

  def execute
    invite = UserInvite.create!(
      company: resource, email: email, role: role,
      invited_by: current_user
    )
    UserInviteMailer.invitation(invite).deliver_later
    succeed(resource).with_message("Invitation sent to #{email}")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end

  def not_already_invited
    return unless email.present?
    if UserInvite.exists?(company: resource, email: email, state: :pending)
      errors.add(:email, "already has a pending invitation")
    end
  end

  def current_user = view_context.controller.helpers.current_user
end
```

---

## Related Skills

- [[plutonium-resource]] — registering interactions as actions; field/input/display syntax
- [[plutonium-tenancy]] — `relation_scope`, entity scoping, nested resources
- [[plutonium-ui]] — custom interaction form templates, page classes
- [[plutonium-testing]] — testing controllers, policies, interactions
