---
name: plutonium-resource
description: Use BEFORE creating, scaffolding, or editing any Plutonium resource — model, definition, field types, scaffold options, has_cents, SGID, search/filters/scopes/sorting, custom actions, bulk actions, hidden actions, index views, drag-to-reorder (positioned_on / position_on), page customization. The single source for "what is a resource and how do I configure one".
---

# Plutonium Resources

A resource = model + migration + controller + policy + definition. This skill covers all three of: **creating** the resource, the **model** layer, and the **definition** (UI, fields, query, actions).

For tenancy / `associated_with` / `relation_scope`, load [[plutonium-tenancy]]. For policy bodies, load [[plutonium-behavior]] (controllers + policies + interactions). For custom Phlex components, load [[plutonium-ui]].

## 🚨 Critical (read first)

- **Always use generators.** `pu:res:scaffold` creates the resource; `pu:res:conn` connects it to a portal. Never hand-write the model, migration, policy, definition, or controller.
- **Pass `--dest`** on every scaffold: `--dest=main_app` or `--dest=package_name`. Skips the interactive prompt.
- **Quote field args with `?` or `{}`** to prevent shell expansion: `'field:type?'`, `'field:decimal{10,2}'`.
- **Run `pu:res:conn` next** — without it the resource has no portal routes and is invisible.
- **Let auto-detection work.** Plutonium reads your model. Only declare `field`/`input`/`display`/`column` when overriding the default.
- **Authorization is in policies, not `condition:` procs.** Use `condition` for UI state ("show this when published"). Use the policy's `permitted_attributes_for_*` for "who can see this".
- **Custom actions require a policy method.** `action :publish` needs `def publish?` on the policy.
- **`has_cents` virtual accessor** — reference `:price`, NEVER `:price_cents`, in policies and definitions.

---

## 🛑 Before you scaffold or edit: confirm the shape (ASK — don't infer)

"Add a Product" / "add a status field" is underspecified. Guess wrong and you scaffold into the wrong package, churn migrations, store money as a lossy float, reference a model that doesn't exist, or **clobber files the user has customized**. Resolve each — **by inspecting (next section), not guessing** — then restate the resolved shape and confirm:

1. **New resource, or editing an existing one?** Existing ⇒ **NEVER re-run `pu:res:scaffold`** (it overwrites the customized model/definition/policy/controller). Add an incremental migration + hand-edit. Confirm by reading the files *first*.
2. **Destination & portal.** `--dest=main_app` or a package? Which portal does `pu:res:conn` wire it to? Both are **required** and unguessable from the request.
3. **Field types — and the money question.** A monetary field ⇒ `has_cents` (`price_cents:integer` + `has_cents :price_cents`, reference `:price`), **never a bare `decimal`**. Enums, attachments (`:attachment`/`:attachments`), rich text, references each have specific syntax (§ Field Type Syntax). Confirm types rather than inventing them.
4. **Referenced associations must already exist.** `category:belongs_to` silently targets a `Category` — if that model isn't there, scaffold it first.
5. **Beyond columns:** does it need search / filters / scopes / custom or bulk actions? Those live in the definition + policy, not the scaffold — name them now so you don't half-build.

**Never emit applied scaffold commands from a guessed `--dest`, portal, or money-shape.** Confirm or read them first; fall back to `AskUserQuestion` only for product choices you can't read off the code (which portal, is `price` money). The decisions compound: *existing+customized ⇒ migration not scaffold*; *money ⇒ `has_cents` + `:price` in the policy*; *new reference ⇒ target model must exist*.

## ✅ Before you touch files: verify the ground truth (CHECK — read it, don't ask for it)

You have file access — **use it.** "Paste me the model" is a fallback for when you genuinely can't read the repo, not the default.

| Check | How | Why it matters |
|---|---|---|
| Resource already exists | Read `app/models/<x>.rb` + `app/**/definitions/<x>_definition.rb`; `ls` the policy/controller | Existing + customized ⇒ **incremental edit, never re-scaffold** |
| Model is a resource record | grep `Plutonium::Resource::Record` / `< ResourceRecord` | Auto-detection + the field DSL depend on it |
| Name collision | Read `db/schema.rb` for the column; grep the model for an existing method/enum/assoc of that name | A clashing `status` silently breaks the enum |
| Referenced association target | `ls app/models` for the `belongs_to` target class | `x:belongs_to` to a missing model fails the scaffold |
| `has_cents` policy leak | grep the policy/definition for `_cents` | Generator emits `:price_cents`; fix to the virtual `:price` |
| Migrations applied | `rails db:migrate:status` before `pu:res:conn` | Unmigrated / unconnected ⇒ the resource is invisible |

Inspect with your own tools **before** proposing commands or edits.

## 🛠 Use the generator — and don't clobber

Never hand-write the initial model, migration, policy, definition, or controller. Reach for the generator; quote args with `?`/`{}`; pass `--dest=`.

| Task | Generator | Verify first |
|---|---|---|
| New resource | `pu:res:scaffold Model field:type … --dest=` | `--dest` confirmed; referenced models exist |
| Connect to a portal | `pu:res:conn Model --dest=portal` | Migrations are run |
| Regenerate model from columns | `pu:res:scaffold Model --no-migration` | ⚠ **regenerates the model file** — review the diff; overwrites customizations |
| Add a field to an **existing, customized** resource | `rails g migration AddXToYs …` + hand-edit model/definition/policy | This resource was already scaffolded — re-scaffolding clobbers it |

---

# Part 1 — Creating a Resource

## Quick checklist

1. Pick destination: `--dest=main_app` or `--dest=package_name`.
2. Run `rails g pu:res:scaffold ResourceName field:type ... --dest=<dest>`.
3. Review the generated migration — add cascade deletes, composite indexes, defaults.
4. `rails db:prepare`.
5. `rails g pu:res:conn ResourceName --dest=<portal_name>`.
6. Customize the policy's `permitted_attributes_for_*` as needed.
7. Open the portal route in the browser.

## Command Syntax

```bash
rails g pu:res:scaffold MODEL_NAME \
    field1:type \
    field2:type \
    --dest=DESTINATION
```

Quote any field with `?` or `{}`:

```bash
'field:type?'              # nullable
'field:decimal{10,2}'      # options
'field:decimal?{10,2}'     # both
```

## Field Type Syntax

Format: `name:type[?][{options}][:index_type]`

- `?` after the type → nullable (`null: true` in migration, `optional: true` on `belongs_to`)
- `{...}` → type options: `{default:X}`, `{10,2}` precision/scale, `{class_name:User}`
- `:index_type` → `index` (regular) or `uniq` (unique)
- Quote any field containing `?` or `{}` to prevent shell expansion

### Basic Types

| Syntax | Result |
|--------|--------|
| `name:string` | Required string |
| `'name:string?'` | Nullable string |
| `age:integer` | Required integer |
| `'age:integer?'` | Nullable integer |
| `active:boolean` | Required boolean |
| `'active:boolean?'` | Nullable boolean |
| `content:text` | Required text |
| `'content:text?'` | Nullable text |
| `birth_date:date` | Required date |
| `'anniversary:date?'` | Nullable date |
| `starts_at:datetime` | Required datetime |
| `'ends_at:datetime?'` | Nullable datetime |
| `alarm_time:time` | Required time |
| `'reminder_time:time?'` | Nullable time |
| `metadata:json` | JSON field |
| `settings:jsonb` | JSONB (PostgreSQL + SQLite) |
| `external_id:uuid` | UUID field |

### PostgreSQL-Specific Types

Auto-mapped to SQLite equivalents when needed:

| Type | PostgreSQL | SQLite |
|------|------------|--------|
| `jsonb` | `jsonb` | `json` |
| `hstore` | `hstore` | `json` |
| `uuid` | `uuid` | `string` |
| `inet` | `inet` | `string` |
| `cidr` | `cidr` | `string` |
| `macaddr` | `macaddr` | `string` |
| `ltree` | `ltree` | `string` |

### Default Values

```bash
'status:string{default:draft}'
'active:boolean{default:true}'
'priority:integer{default:0}'
'rating:float{default:4.5}'
'status:string?{default:pending}'
```

JSON/JSONB defaults (parsed as JSON first, then string fallback):

```bash
'metadata:jsonb{default:{}}'
'tags:jsonb{default:[]}'
'settings:jsonb{default:{"theme":"dark"}}'
'config:jsonb?{default:{}}'
```

### Decimal with Precision

```bash
'amount:decimal{10,2}'                   # precision: 10, scale: 2
'price:decimal{10,2,default:0}'          # with default
'balance:decimal?{15,2,default:0}'       # nullable + default
```

### References / Associations

```bash
company:belongs_to                       # required FK
'parent:belongs_to?'                     # nullable (null: true + optional: true)
user:references                          # same as belongs_to
blogging/post:belongs_to                 # cross-package reference
'author:belongs_to{class_name:User}'     # custom class_name
'reviewer:belongs_to?{class_name:User}'  # nullable + class_name
```

### Index Types (third segment)

```bash
email:string:index     # regular index
email:string:uniq      # unique index
```

### Special Types

```bash
password_digest        # has_secure_password
auth_token:token       # has_secure_token (auto unique index)
content:rich_text      # has_rich_text
avatar:attachment      # has_one_attached
photos:attachments     # has_many_attached
price_cents:integer    # use with has_cents in model
```

## Generator Options

- `--dest=DESTINATION` — `main_app` or `package_name` (**required**)
- `--no-model` — skip model file
- `--no-migration` — skip migration

For existing models that already include `Plutonium::Resource::Record`:

```bash
rails g pu:res:scaffold Post --no-migration --dest=main_app
```

Run with no fields to auto-import from `model.content_columns` (regenerates the model file — review the diff).

## What Gets Generated

**Main app:**
- `app/models/model_name.rb`
- `db/migrate/xxx_create_model_names.rb`
- `app/controllers/model_names_controller.rb`
- `app/policies/model_name_policy.rb`
- `app/definitions/model_name_definition.rb`

**Packaged** (paths nested under `packages/package_name/...` for controller/policy/definition; model and migration stay at app root with namespace).

## Migration Customizations

Always review before migrating. Per project convention, **inline indexes/FKs in the create_table block**:

```ruby
create_table :model_names do |t|
  t.belongs_to :parent, null: false, foreign_key: {on_delete: :cascade}
  t.string :name, null: false

  t.timestamps

  t.index :name
  t.index [:parent_id, :name], unique: true
end
```

For non-trivial defaults, edit the migration directly:

```ruby
t.datetime :published_at, default: -> { "CURRENT_TIMESTAMP" }
```

## Examples

```bash
# Main app resource with associations and a nullable text field
rails g pu:res:scaffold Post \
    user:belongs_to \
    title:string \
    'content:text?' \
    'published_at:datetime?' \
    --dest=main_app

# Precision + indexes
rails g pu:res:scaffold Property \
    company:belongs_to \
    code:string:uniq \
    'latitude:decimal{11,8}' \
    'value:decimal?{15,2}' \
    --dest=main_app

# Cross-package reference
rails g pu:res:scaffold Comment \
    user:belongs_to \
    blogging/post:belongs_to \
    body:text \
    --dest=comments
```

---

# Part 2 — The Model Layer

## What `Plutonium::Resource::Record` provides

| Module | Purpose |
|--------|---------|
| `HasCents` | Monetary values (cents ↔ decimal) |
| `Routes` | URL params, `to_param` customization |
| `Labeling` | `to_label` for human-readable names |
| `FieldNames` | Field introspection by category |
| `Associations` | SGID methods on every association |
| `AssociatedWith` | Multi-tenant scoping (see [[plutonium-tenancy]]) |

Standard setup (created by `pu:core:install`):

```ruby
class ApplicationRecord < ActiveRecord::Base
  include Plutonium::Resource::Record
  primary_abstract_class
end

class ResourceRecord < ApplicationRecord
  self.abstract_class = true
end
```

## Section Order

The scaffold lays out resource models in a strict order — keep new code in the right section so files stay scannable:

1. Concerns (`include`)
2. Constants (`TYPES = {...}.freeze`)
3. Enums
4. Model configurations (`has_cents`)
5. `belongs_to`
6. `has_one`
7. `has_many`
8. Attachments (`has_one_attached`, `has_many_attached`)
9. Scopes
10. Validations
11. Callbacks
12. Delegations
13. Misc macros (`has_rich_text`, `has_secure_token`, `has_secure_password`)
14. Public methods, then `private`, then private methods

Example:

```ruby
class Property < ResourceRecord
  TYPES = {apartment: "Apartment", house: "House"}.freeze

  enum :state, archived: 0, active: 1

  has_cents :market_value_cents

  belongs_to :company
  has_one :address
  has_many :units

  has_one_attached :photo

  scope :active, -> { where(state: :active) }

  validates :name, presence: true
  validates :property_code, presence: true, uniqueness: {scope: :company_id}

  before_validation :generate_code, on: :create

  has_rich_text :description

  def full_address
    address&.to_s
  end

  private

  def generate_code
    self.property_code ||= SecureRandom.hex(4).upcase
  end
end
```

## Monetary Handling (`has_cents`)

Stores money as integer cents; exposes a decimal virtual accessor.

```ruby
class Product < ResourceRecord
  has_cents :price_cents                    # virtual :price (default rate 100)
  has_cents :cost_cents, name: :wholesale   # custom accessor name
  has_cents :tax_cents, rate: 1000          # 3 decimal places
end

product.price = 19.99
product.price_cents  # => 1999
product.price        # => 19.99

# Truncates, doesn't round
product.price = 10.999
product.price_cents  # => 1099
```

**Critical: in policies and definitions, reference the virtual accessor (`:price`), NOT the column (`:price_cents`).** Generators sometimes emit `_cents` in the policy — fix by hand:

```ruby
# Policy
permitted_attributes_for_create { %i[name price] }   # NOT :price_cents

# Definition
field :price, as: :decimal
```

Validation on the cents column propagates a generic error to the virtual:

```ruby
validates :price_cents, numericality: {greater_than: 0}
# product.errors[:price]       => ["is invalid"]
# product.errors[:price_cents] => ["must be greater than 0"]
```

## SGID on Associations

Every association gets Signed Global ID methods for secure serialization (form params, API payloads, hidden fields).

```ruby
class Post < ResourceRecord
  belongs_to :user
  has_many :tags
end

post.user_sgid           # singular: get
post.user_sgid = "..."   # singular: set

post.tag_sgids                # collection: get array
post.tag_sgids = [...]        # collection: bulk replace
post.add_tag_sgid("...")      # collection: append
post.remove_tag_sgid("...")   # collection: remove
```

## URL Routing

`path_parameter` and `dynamic_path_parameter` are **class-level macros** (private class methods) — call them in the class body, not as instance methods.

```ruby
# Default: numeric id
user.to_param  # => "1"

# Stable, unique field
class User < ResourceRecord
  path_parameter :username
end
# /users/john_doe

# SEO-friendly: id + slug
class Article < ResourceRecord
  dynamic_path_parameter :title
end
# /articles/1-my-great-article

Article.from_path_param("1-my-great-article")  # extracts id, finds by id
User.from_path_param("john_doe")               # finds by username
```

## Labeling

```ruby
# Auto: tries :name, then :title, then "User #1"
user.to_label

# Override
class Product < ResourceRecord
  def to_label = "#{name} (#{sku})"
end
```

## Field Introspection

```ruby
User.resource_field_names                   # all fields
User.content_column_field_names             # DB columns
User.belongs_to_association_field_names
User.has_one_association_field_names
User.has_many_association_field_names
User.has_one_attached_field_names
User.has_many_attached_field_names
```

---

# Part 3 — The Definition Layer

Definitions configure **how** a resource is rendered and interacted with.

🚨 **Do NOT declare a `field` / `input` / `display` / `column` unless you are overriding an auto-detected default.** Plutonium reads the model and renders every attribute automatically — type, label, form widget, display formatter, column. Declaring it again with no new options is dead code; declaring it with the same `as:` Plutonium already inferred is dead code; listing every field "for completeness" is dead code. If the only reason you're adding a line is "so the field shows up", delete it — it already shows up. Declare ONLY when you need: a different type (`as: :markdown`), a custom option (`hint:`, `placeholder:`, `wrapper:`), a `condition:`, a custom block, or a custom component.

File locations:

- Main app: `app/definitions/model_name_definition.rb`
- Packages: `packages/pkg_name/app/definitions/pkg_name/model_name_definition.rb`

## Hierarchy

```ruby
# app/definitions/resource_definition.rb (base, created at install)
class ResourceDefinition < Plutonium::Resource::Definition
  action :archive, interaction: ArchiveInteraction, color: :danger, position: 1000
end

# app/definitions/post_definition.rb (scaffold)
class PostDefinition < ResourceDefinition
  scope :published
  input :content, as: :markdown
end

# Portal override (per-portal customization)
class AdminPortal::PostDefinition < ::PostDefinition
  scope :pending_review
  input :internal_notes, hint: "Not shown to the author"
end
```

## Core Methods

| Method | Applies To | Use When |
|--------|-----------|----------|
| `field` | Forms + Show + Table | Universal type override |
| `input` | Forms only | Form-specific options |
| `display` | Show page only | Display-specific options |
| `column` | Table only | Table-specific options |

```ruby
class PostDefinition < ResourceDefinition
  field :content, as: :markdown                 # everywhere
  input :title, hint: "Be descriptive"
  display :content, wrapper: {class: "col-span-full"}
  column :view_count, align: :end
end
```

## Separation of Concerns

| Layer | Purpose | Example |
|-------|---------|---------|
| Definition | HOW fields render | `input :content, as: :markdown` |
| Policy | WHAT is visible/editable | `permitted_attributes_for_read` |
| Interaction | Business logic | `resource.update!(state: :archived)` |

## Available Field Types

### Input Types (forms)

| Category | Types |
|----------|-------|
| Text | `:string`, `:text`, `:email`, `:url`, `:tel`, `:password` |
| Rich Text | `:markdown` (EasyMDE) |
| Numeric | `:number`, `:integer`, `:decimal`, `:range` |
| Boolean | `:toggle` / `:switch` (switch — **default** for boolean columns), `:boolean` (plain checkbox) |
| Date/Time | `:date`, `:time`, `:datetime` |
| Selection | `:select`, `:slim_select`, `:radio_buttons`, `:check_boxes` |
| Files | `:file`, `:uppy`, `:attachment` |
| Associations | `:association`, `:secure_association`, `:belongs_to`, `:has_many`, `:has_one` |
| Special | `:hidden`, `:color`, `:phone` |

### Display Types (show / index)

`:string`, `:text`, `:email`, `:url`, `:phone`, `:markdown`, `:number`, `:integer`, `:decimal`, `:boolean`, `:badge`, `:currency`, `:color`, `:date`, `:time`, `:datetime`, `:association`, `:attachment`

#### Auto-inferred display formatting

These render automatically — declare an `as:` only to override or pass options:

| Column | Renders as | Notes |
|--------|-----------|-------|
| `boolean` | Yes/No pill (`:boolean`) | green "Yes" / neutral "No". Override labels: `true_label:`, `false_label:` |
| `enum` | colored status badge (`:badge`) | known statuses (active, pending, failed…) auto-colored; unknown values get a stable decorative color |
| `has_cents` decimal | currency (`:currency`) | delimited, 2 decimals, **no symbol** unless you add `unit:` |

```ruby
display :status, as: :badge, colors: {archived: :neutral, vip: :accent}  # override per-value color
display :price,  as: :currency, unit: "£"                                # literal symbol
display :price,  as: :currency, unit: :currency_symbol                   # Symbol → read off the record (per-row)
display :active, as: :boolean,  true_label: "Live", false_label: "Off"
```

Badge color keys: `:neutral`, `:primary`, `:secondary`, `:success`, `:danger`, `:warning`, `:info`, `:accent`.

## Field Options

```ruby
input :title,
  label: "Custom Label",
  hint: "Help text",
  placeholder: "Enter value",
  description: "For displays",   # appears on show page

  # tag-level HTML
  class: "custom-class",
  data: {controller: "custom"},
  required: true,
  readonly: true,
  disabled: true,

  # wrapper
  wrapper: {class: "col-span-full"}
```

## Select / Choices

```ruby
# Static
input :category, as: :select, choices: %w[Tech Business Lifestyle]
input :status, as: :select, choices: Post.statuses.keys

# Dynamic — must use a block
input :author do |f|
  f.select_tag choices: User.active.pluck(:name, :id)
end

# With context (current_user, object, params, request available in block)
input :team_members do |f|
  f.select_tag choices: current_user.organization.users.pluck(:name, :id)
end
```

## Conditional Rendering

```ruby
display :published_at, condition: -> { object.published? }
display :rejection_reason, condition: -> { object.rejected? }
field :debug_info, condition: -> { Rails.env.development? }
```

Use `condition` for UI state; use the policy for authorization.

## Options That Vary Per Render

Any option may be a **proc**, resolved on every render rather than frozen at class load. Holds across the whole form DSL — `field`, `input`, `section`/`ungrouped`, `structured_input`, nested inputs. Arity says **whether you want the form**:

```ruby
input :tier,  as: :select, choices: ->(form) { form.object.account.available_tiers }
input :notes, placeholder: -> { "Updated #{Time.current.year}" }
```

- `-> { … }` is called as-is, keeping its own binding — it means what it reads like where you wrote it; nothing rebinds `self`. That is what makes `choices: -> { reviewer_choices }` work inside an interaction's `customize_inputs` (private helpers included).
- `->(form) { … }` gets the form — `object` (the record), `params`, view helpers.

Same rule on wizard steps — but a step block closes over an internal field recorder, so options there must take the form: `->(form) { form.wizard.anchor.tiers }`. See [[plutonium-wizard]].

**`condition:` is not an option — it follows a different rule, for a reason.** An option asks "what value should this have?", so it may not care about the render and defaults to meaning what it reads like. `condition:` asks "should this render *here, now*?" — a question about the render context by definition. So it always runs **against** that context and reads it with no argument, where "context" is whatever is rendering:

```ruby
input   :notes,     condition: -> { object.published? }        # the form
display :audit_log, condition: -> { current_user.admin? }      # the display component
step    :billing,   condition: -> { data.plan.tier == "pro" }  # the wizard — no form exists yet
```

It cannot take a `form` argument the way an option does: for a `column`/`display`, a step, or an action there is no form.

## Dynamic Forms (`pre_submit`)

A `pre_submit: true` field triggers a server re-render on change, re-evaluating `condition:` procs. Use for cascading or context-dependent forms.

```ruby
class QuestionDefinition < ResourceDefinition
  # :select + choices is a real override (model column is just a string)
  input :question_type, as: :select,
    choices: %w[text choice scale],
    pre_submit: true

  # No `as:` — types are auto-detected from the model. We only declare to add `condition:`.
  input :max_length, condition: -> { object.question_type == "text" }
  input :choices,    condition: -> { object.question_type == "choice" }
  input :min_value,  condition: -> { object.question_type == "scale" }
end
```

Dynamic choices follow the same pattern:

```ruby
input :category, as: :select,
  choices: Category.pluck(:name, :id),
  pre_submit: true

input :subcategory do |f|
  choices = object.category.present? ?
    Category.find(object.category).subcategories.pluck(:name, :id) : []
  f.select_tag choices: choices
end
```

Tips:
- Only add `pre_submit:` to fields that gate visibility of others.
- Avoid on frequently-changed fields (every keystroke = submit).

## Custom Rendering

**Display block — return any component:**

```ruby
display :status do |field|
  StatusBadgeComponent.new(value: field.value, class: field.dom.css_class)
end
```

**Input block — must use form builder methods:**

```ruby
input :birth_date do |f|
  case object.age_category
  when 'adult' then f.date_tag(min: 18.years.ago.to_date)
  when 'minor' then f.date_tag(max: 18.years.ago.to_date)
  else f.date_tag
  end
end
```

**`phlexi_tag` for declarative custom display.** The `with:` option takes either a Phlex component class, or a proc whose body is **rendered inside a Phlex context** — so HTML tags (`span`, `div`, `a`, …) and Tailwind classes are first-class. The proc receives `(value, attrs)` where `value` is the field value and `attrs` are wrapper attributes.

```ruby
# Component class — preferred for anything reusable
display :status, as: :phlexi_tag, with: StatusBadgeComponent

# Inline Phlex proc — `span` here is a Phlex tag method, not Ruby/Rails
display :priority, as: :phlexi_tag, with: ->(value, attrs) {
  case value
  when 'high'   then span(class: "badge badge-danger")  { "High" }
  when 'medium' then span(class: "badge badge-warning") { "Medium" }
  else span(class: "badge badge-info") { "Low" }
  end
}
```

See [[plutonium-ui]] for writing custom Phlex components.

**Custom component classes** (Phlex components — see [[plutonium-ui]]). `as:` takes a **field component**, constructed as `YourComponent.new(field, **attributes)` — subclass `Phlexi::Form::Components::Base` (inputs) or `Phlexi::Display::Components::Base` (displays) and read the value off `field`:

```ruby
input :color_picker, as: ColorPickerComponent
display :chart, as: ChartComponent
```

🚨 A component with its own constructor (`PostCardComponent.new(post:)`) is NOT an `as:` candidate — it raises `ArgumentError`. Build it in a block instead:

```ruby
display :card do |field|
  PostCardComponent.new(post: field.object)
end
```

## Column Options

```ruby
column :title, align: :start     # :start (default), :center, :end
column :amount, align: :end

# formatter — receives just the value
column :price, formatter: ->(v) { "$%.2f" % v if v }

# block — receives the full record
column :full_name do |record|
  "#{record.first_name} #{record.last_name}"
end
```

## Nested Inputs

Inline forms for associated records. Requires `accepts_nested_attributes_for` on the model.

```ruby
class Post < ResourceRecord
  has_many :comments
  has_one :metadata

  accepts_nested_attributes_for :comments, allow_destroy: true, limit: 10
  accepts_nested_attributes_for :metadata, update_only: true
end

class PostDefinition < ResourceDefinition
  nested_input :comments do |n|
    n.input :body, as: :text
    n.input :author_name
  end

  nested_input :metadata, using: PostMetadataDefinition, fields: %i[seo_title seo_description]
end
```

### Options

| Option | Description |
|--------|-------------|
| `limit` | Max records (auto-detected from model, default 10) |
| `allow_destroy` | Show delete checkbox (auto-detected) |
| `update_only` | Hide "Add" button — only edit existing |
| `description` | Help text above section |
| `condition` | Proc to show/hide |
| `using` | Another Definition class |
| `fields` | Subset of fields from the referenced definition |

### Gotchas

- Model needs `accepts_nested_attributes_for`.
- The child's `belongs_to` **must** declare `inverse_of: :parent_assoc`. Without it, in-memory validation fails with "Parent must exist" because the parent isn't saved yet.
- **Do NOT put `*_attributes` hashes in `permitted_attributes_for_*`.** Plutonium extracts nested params via the form definition, not the policy. The policy permits just the association name (`:variants`); `nested_input :variants` handles the rest.
- For custom class names, use `class_name:` in the model and `using:` in the definition.
- `update_only: true` hides the Add button.

## Structured Inputs

`structured_input` collects a **classless** group of fields — a single hash, or
(with `repeat:`) an array of hashes. No association or model class is involved.
On resources the value is stored in a **JSON/jsonb column**; use it when you
want structured data in a JSON column rather than a real association (which is
`nested_input`'s job).

```ruby
class Spec < ResourceRecord
  # t.json :payload   /   t.json :rows  (jsonb in production)
end

class SpecDefinition < ResourceDefinition
  structured_input :payload do |f|       # single → { title:, notes: }
    f.input :title
    f.input :notes
  end

  structured_input :rows, repeat: 5 do |f|  # repeater → [ { key:, value: }, ... ] (max 5)
    f.input :key
    f.input :value
  end
end

class SpecPolicy < ResourcePolicy
  # NOTE: unlike nested_input, you DO permit the column name here.
  # (update inherits permitted_attributes_for_create automatically.)
  def permitted_attributes_for_create = [:payload, :rows]
end
```

`execute`/the record sees `payload => { "title" => …, "notes" => … }` and
`rows => [ { "key" => …, "value" => … }, … ]` (string keys from the JSON column;
blank rows are dropped, `_destroy` stripped).

### Options

| Option | Description |
|--------|-------------|
| `repeat` | Presence ⇒ array (repeater). `Integer` = max rows; `true` = default cap (10); absent = single hash |
| `using` | A fields definition class instead of a block |
| `fields` | Subset of fields from the referenced definition |

### Gotchas

- The column must be `json`/`jsonb` (or otherwise hold a hash/array). No model macro is needed — the value assigns directly.
- **Unlike `nested_input`, you DO permit the column name** in `permitted_attributes_for_*` (it's a regular attribute on a JSON column).
- `repeat: 1` is "array, max one row" — **not** the single form. Presence of `repeat:` always means an array.
- Rows are positional plain hashes — **no ids, no per-row class, no type coercion**.
- **No automatic validation.** Classless ⇒ nothing to attach `validates` to. `required:` and a select's `choices:` are **client-side only**, not enforced on the server. To enforce, add a model `validate` (resource) or a `validate` on the interaction (ActiveModel, checked before `execute`).
- **`as: :select` drops unknown values.** If a stored value isn't in `choices:`, the `<select>` renders blank and **saving overwrites it with `nil`** (standard `<select>` behaviour). Keep `choices:` a stable superset or use free text when values can drift.
- Inside repeater rows, prefer **native** field types (string, number, text, native `select`, checkbox). JS-enhanced inputs (slim-select, flatpickr, easymde, uppy, intl-tel) transform the DOM and may not survive the repeater's clone-by-innerHTML — verify before relying on them.
- Same DSL works on **interactions** (see [[plutonium-behavior]] › Interactions) — there it backs an ActiveModel attribute reaching `execute`.

## File Uploads

```ruby
input :avatar, as: :file
input :avatar, as: :uppy
input :documents, as: :file, multiple: true
input :documents, as: :uppy,
  allowed_file_types: ['.pdf', '.doc'],
  max_file_size: 5.megabytes
```

## Block Context

Inside `condition` procs and block-form `input`/`display`:

- `object` — the record
- `current_user`
- `current_parent` — for nested resources
- `request`, `params`
- All helper methods

## Runtime Customization Hooks

For dynamic per-request logic, override:

```ruby
def customize_fields    # add/modify fields
def customize_inputs    # add/modify inputs
def customize_displays  # add/modify displays
def customize_filters
def customize_actions
```

## Form & Page Configuration

```ruby
class PostDefinition < ResourceDefinition
  # "Save and add another" / "Update and continue editing"
  # nil (default) = auto (hidden for singular, shown for plural)
  submit_and_continue false

  # How :new / :edit + interactive actions render
  #   :slideover (default), :centered, or false (full pages)
  #   size: :sm / :md (default) / :lg / :xl / :auto / :full
  modal :centered, size: :lg

  # Titles
  index_page_title "All Posts"
  show_page_title -> { "#{current_record!.title} - Details" }

  # Breadcrumbs
  breadcrumbs true
  show_page_breadcrumbs false

  # Custom page classes — inherit from the parent's nested class
  class IndexPage < IndexPage
    def view_template(&block)
      div(class: "custom-header") { h1 { "Custom" } }
      super(&block)
    end
  end

  class Form < Form
    def form_template
      div(class: "grid grid-cols-2") do
        render field(:title).input_tag
        render field(:content).easymde_tag
      end
      render_actions
    end
  end
end
```

`modal:` is the default for framework `:new` / `:edit` *and* every interactive action on this definition. Per-action `modal:` / `size:` overrides win.

## Form Layout (`form_layout`)

Group form fields into sections **declaratively in the definition** — no `Form` subclass, no view code. Prefer this over hand-rolling a `section` helper in a custom `form_template`.

```ruby
class PostDefinition < ResourceDefinition
  form_layout do
    section :identity, :name, :email, label: "Identity", description: "Who this is"
    section :address, :street, :city,
      collapsible: true, collapsed: ->(form) { form.object.persisted? }, columns: 2,
      condition: -> { object.requires_address? }   # hide the whole section as a unit
    ungrouped label: "Other"                        # bucket for unlisted fields; position = where it renders
  end
end
```

- **Layout references field KEYS only** — all per-field config (`as:`, `hint:`, blocks, per-field `condition:`) stays on `input`. Never duplicated here.
- **Options**: `label:`, `description:`, `collapsible:`, `collapsed:`, `columns:` (positive Integer, literal only), `condition:`. Every option except `columns:` may be a **proc**, resolved at render under the same arity rule as any other option — take a `form` argument to read the render context.
- ⚠️ **Breaking in 0.63**: section options used to take a zero-arg proc run *against* the form. They now follow the shared rule, and a `form_layout` block is evaluated against the layout builder, so a bare `object` is a `NameError`. Migrate `collapsed: -> { object.persisted? }` → `collapsed: ->(form) { form.object.persisted? }`. `condition:` is unchanged (still form-evaluated, still reads `object` with no argument).
- **Absent fields are skipped.** A key the section lists that isn't in the permitted set (policy, per-action, scoping, nesting, or a typo) is silently dropped — never an error. The same layout serves a richly-permitted `edit` and a minimal `new`.
- **🚨 Zero-field sections drop entirely** — no heading, no grid. So `+ New` (fewer permitted attributes) won't sprout empty headings. This checks *field presence only*; per-field `condition:` runs later, so to hide a whole section by state, gate it with the **section's own `condition:`**, not by hiding every field inside it.
- **Works on interactions too** (`Plutonium::Interaction::Base`) — groups `attribute` declarations. There `object` is the interaction instance; for record actions the record is `object.resource`.

Full DSL reference: [Resource › Definition › Form layout](/reference/resource/definition#form-layout).

## Display Layout (`display_layout`)

The show page's counterpart to `form_layout`. Same DSL, same resolution (first-section-wins, unlisted permitted fields fall into `ungrouped`, absent fields skipped, zero-field sections dropped) — applied to the show page's fields instead of the form's.

```ruby
class PostDefinition < ResourceDefinition
  display_layout do
    section :profile, :name, :author, label: "Profile", description: "Identity and owner"
    section :presentation, :cover, :body, collapsible: true
    ungrouped label: "Other details"
  end
end
```

- **Declare both independently.** `form_layout` and `display_layout` are separate registries — a resource can group its form one way and its show page another, or declare only one. Neither inherits from the other.
- **🚨 No `columns:`** — unlike `form_layout`, it **raises**. Every display section shares one responsive grid; field width is a per-field concern: `display :x, wrapper: {class: "col-span-2"}` (works identically inside a section and outside one). Raising rather than ignoring means a copied `form_layout` block fails loudly instead of silently doing nothing.
- **Options**: `label:`, `description:`, `collapsible:`, `collapsed:`, `condition:` — the same set as `form_layout` minus `columns:`. `collapsible: true, collapsed: true` works exactly as it does on forms. Every option except `condition:` may be a **proc**, resolved at render under the same arity rule as the form: take a `display` argument to read `object`.
- **Each section renders as its own card**, so the sectioned show page has no single outer card. Fields declared in `metadata` are excluded (they render in the metadata panel) — see below.

## Page Width (`page_width`)

Detail-style pages — the show page and resource forms — are width-constrained by default. Inputs and values stretch to their container, so at full content width you get ~1200px-long lines. Index/table pages are NOT affected.

```ruby
Plutonium.configure { |c| c.default_page_width = :md }   # global default (:md)

class PostDefinition < ResourceDefinition
  page_width    :lg      # form AND show page
  display_width :full    # ...but the show page opts out
  form_width    :sm      # ...and the form goes narrow
end
```

- **Sizes**: `:sm` `:md` `:lg` `:xl` `:full`. `:full` means no constraint. An unknown value **raises** at declaration.
- **🚨 Tokens are relative to their surface** — the same *names* modals use, but NOT the same widths. Page `:md` is 896px; a centered modal's `:md` is 576px and a slideover's is 480px. A "small page" is deliberately larger than a "small dialog". Modals also have `:auto`; pages don't (nothing to hug).
- **Resolution**: surface-specific (`form_width` / `display_width`) → `page_width` → `Plutonium.configuration.default_page_width`. An explicit `:full` is honoured, not treated as unset.
- **Inherits** to subclasses, so a portal-specific definition keeps the parent's width unless it overrides.
- **Modals are unaffected** — the dialog sets its own width (`modal_size`).
- **Interactions support it too** (`Plutonium::Interaction::Base`), for interactive actions rendered as standalone pages.
- **Wizards are on their own axis** — `Plutonium.configuration.wizards.width` (default `:md`), overridden per wizard with `width`. It does NOT follow `default_page_width`, so changing resource page width leaves wizards untouched.

## Metadata Panel (show page)

Declares fields rendered in the show page's right-side aside as label/value rows.

```ruby
metadata :author, :state, :created_at, :updated_at
```

- **Opt-in** — no call → show page is full-width with no aside.
- **Policy-aware** — fields the user can't see disappear; panel auto-hides if nothing's permitted.
- **Deduplicated** — listed fields are removed from the main details card (and from any `display_layout` section).
- **Responsive** — side-by-side at `lg+`, stacked below.
- **In a modal it stacks below the details**, not beside them: the rail is a fixed-width column on a *viewport* breakpoint, so in a dialog it would split regardless of how narrow the dialog is and crush the main column.
- **A kanban card's modal drops metadata entirely** — the fields are hidden, not folded into the main card.

Use for chrome (timestamps, ownership, system flags), keeping the main card focused on substance.

## Index Views (Table & Grid)

Resources can offer both Table and Grid views; user choice persists per-resource via cookie.

```ruby
class UserDefinition < ResourceDefinition
  # No `index_views :table, :grid` needed — `grid_fields` auto-enables :grid alongside the default :table.
  grid_fields(
    image:     :avatar,           # ActiveStorage, Shrine, or URL
    header:    :name,             # falls back to to_label
    subheader: :email,
    body:      :bio,
    meta:      [:role, :status],  # rendered as small pills
    footer:    :last_seen_at      # falls back to :created_at; `false` to omit
  )

  default_index_view :grid        # optional — initial view when no cookie
  grid_layout :media              # :compact (default) or :media
  grid_columns 3                  # pin lg+ cols; default is 1/2/3/4 responsive
end
```

Only declare `index_views` explicitly if you want to **disable** one (e.g. `index_views :grid` to remove the table view).

| Method | Purpose |
|--------|---------|
| `index_views :table, :grid` | Which views are available. Default `[:table]`. Only declare to disable one. |
| `default_index_view :grid` | Initial view when no cookie. |
| `grid_fields(...)` | Map card slots to fields. **Implicitly enables `:grid`**. |
| `grid_layout :media` | `:compact` (image left) or `:media` (image on top). |
| `grid_columns 3` | Override responsive column count. |

All grid slots are optional; slots pointing at unpermitted fields collapse silently.

---

## Drag-to-Reorder (`positioned_on` + `position_on`)

Manual ordering on the index table, the card grid, and nested association tables. **Two verbs, never three** — the model says how positions are stored, the definition (and a kanban board) says the UI is orderable:

```ruby
# Migration — t.position emits decimal(16,8), tuned for fractional ordering.
create_table :tasks do |t|
  t.string :status, null: false, default: "todo"
  t.position
  t.index [:status, :position]     # match the scope attribute
end

# Model — storage
class Task < ApplicationRecord
  include Plutonium::Positioning::Model    # NOT Plutonium::Positioning
  positioned_on :position, scope: :status  # scope: nil = one global ordering
end

# Definition — "this UI can be reordered". Never restates the column or the scope.
class TaskDefinition < ResourceDefinition
  position_on
end

# Existing rows need positions:
Task.backfill_positions!(order: :created_at)
```

- **`include Plutonium::Positioning::Model`** — the concern used to be `Plutonium::Positioning` itself. A bare `include Plutonium::Positioning` is now wrong (it's a pure namespace). Constants nested in an included concern join the model's constant lookup, so the old form let `Plutonium::Positioning::Config` shadow an app's own `::Config`.
- **`positioned_on` is required**, not just the include — without it there's no `before_create`, so every row is created with a `NULL` position. `position_on` raises at class-load if you forget.

### `position_on` forms and modes

| Form | Mode | Notes |
|---|---|---|
| `position_on` | A (delegate) | Follows the model's `positioning_column`. **Prefer this** — it cannot disagree with the model. |
| `position_on :sort_order` | A | Must **match** the model's column, else `ArgumentError` at class-load |
| `position_on(:rank) { \|move\| … }` | B (block) | Escape hatch — another gem owns the write (`acts_as_list`). No model concern needed. **Prefer migrating to A.** |
| `position_on false` | C (disabled) | No ordering, no route — the endpoint 404s |

**Default to Mode A.** It is one word in the definition. A *correct* Mode B block is ~15 lines of rank arithmetic, and getting it right requires knowing three non-obvious things: `move.index` is page-relative; removing a record shifts its neighbours' ranks by one, in a direction that depends on where it started; and a blank `move.prev` means "nothing above me *on screen*", not "top of the list". These docs got two of the three wrong until they were tested. Mode B is legitimate and tested — it just costs you semantics Mode A handles.

### Mode B — what the framework stops doing

Mode B block receives a `Plutonium::Positioning::Move`: `record`, `prev`, `next`, `index` (0-based, **relative to the visible page**), `column` (kanban only, `nil` on tables/grids). Called with `call`, not `instance_exec`.

Because the write is opaque, three Mode A behaviours are **not** provided:

- **No hidden boundary resolution** — `resolve_position_boundaries` returns early unless the config delegates, so the block gets the client's viewport verbatim, `nil`s and all.
- **No server-side foreign-sort rejection** — Mode A rejects a drop under a foreign sort with 422 before writing; Mode B relies on the client-side gate only.
- **Always a full repaint** — never 204. Gems like `acts_as_list` renumber the whole group on every move, so the client's optimistic DOM is stale by definition.

### Migrating off `acts_as_list` to Mode A

1. **Change the column** — `acts_as_list` uses contiguous integers; Plutonium uses fractional decimals (`t.position` emits `decimal(16,8)`; an integer column would round every midpoint onto a neighbour). `t.position` *adds* a column, so an existing one needs `change_column :tasks, :position, :decimal, precision: 16, scale: 8`.
2. **Swap the macro** — drop `acts_as_list scope: [:status]`, add `include Plutonium::Positioning::Model` + `positioned_on :position, scope: :status` (bare Symbol; the Array trap is gem-specific).
3. **Backfill** — `Task.backfill_positions!(order: :position)` numbers each scope group `1.0, 2.0, …` in the gem's existing order. `update_column`, no callbacks/validations/`updated_at` — run it once from a migration or `rails runner`.
4. Drop the block from the definition; a bare `position_on` is the whole of Mode A.

### Staying on `acts_as_list` (the harder road)

For when the gem is not yours to remove. This recipe is correct and tested against the real gem (`test/plutonium/resource/controllers/position_actions_acts_as_list_test.rb`).

🚨 **Anchor off `move.prev` / `move.next`, never off `move.index`.** `move.index` counts the visible page; a positioning gem's `insert_at` addresses the whole group. `insert_at(move.index + 1)` is wrong on any list past 20 rows (Plutonium's default page size) — measured: dragging rank 25 into the middle of page 2 lands it at **rank 2**, and a page-2 top drop lands at **rank 1**. Same failures on a filtered list.

```ruby
# Keeping acts_as_list. NOTE scope: [:status] — a bare Symbol scope is run
# through acts_as_list's `idify`, which turns :status into :status_id and makes
# every create raise NoMethodError.
class Task < ApplicationRecord
  acts_as_list scope: [:status]
end

class TaskDefinition < ResourceDefinition
  position_on :position do |move|
    record = move.record

    target =
      if move.prev
        # Removing the record shifts prev up one when the record was above it.
        (record.position > move.prev.position) ? move.prev.position + 1 : move.prev.position
      elsif move.next
        # Blank prev means "nothing above me ON MY SCREEN" — rows may still sit
        # above off-page or behind a filter, so anchor off next rather than 1.
        (record.position < move.next.position) ? move.next.position - 1 : move.next.position
      else
        1 # the only row in the list
      end

    record.insert_at(target)
  end
end
```

`insert_at` calls `save`, not `save!` — a failed move silently no-ops. Use `insert_at!` to surface it as a 422.

### 🚨 `position_on` expands to three things

```ruby
sort <attr>                      # load-bearing: the only way back to position order
default_sort <attr>, :asc        # ⚠ ONLY when default_sort is still the framework default
action :reposition, hidden: true # route + policy predicate, no button
```

**The `default_sort` claim is implicit.** A resource that listed newest-first will list in position order after you add `position_on`. Declare your own `default_sort` (above OR below `position_on` — resolution is order-independent) to keep it; note the list then opens **not** draggable.

### Behavior notes

- **Dragging is offered only while the collection is sorted ascending by the position attribute** (and nothing else). Under any other sort the grip renders as a **link that applies that sort**, and the server rejects the drop with 422 before writing.
- **`reposition?` policy predicate**, defaulting to `update?`. Gates both the drop and whether the grip renders per row. `index?` is also required (you must be able to see a list to reorder it).
- **A kanban board inherits the definition's `position_on`** (lazily, so order in the class body doesn't matter); a `position_on` inside `kanban do…end` overrides it.
- **`scope:` is the model author's job.** A globally positioned model rendered under a parent still reorders correctly per parent — but a rebalance renumbers every row in the table, not just that parent's.
- Native HTML5 drag doesn't fire on **touch** devices (same limitation as kanban). Keyboard works: focus the grip, <kbd>↑</kbd>/<kbd>↓</kbd>.

Full reference: `docs/reference/positioning.md`. Kanban specifics: `docs/reference/kanban/positioning.md`.

---

# Part 4 — Query: Search, Filters, Scopes, Sorting

```ruby
class PostDefinition < ResourceDefinition
  search do |scope, q|
    scope.where("title ILIKE ?", "%#{q}%")
  end

  filter :title, with: :text, predicate: :contains
  filter :status, with: :select, choices: %w[draft published archived]
  filter :published, with: :boolean
  filter :created_at, with: :date_range

  scope :published
  default_scope :published

  sort :title
  sort :created_at
  default_sort :created_at, :desc
end
```

## Search

```ruby
# Multi-field with associations
search do |scope, query|
  scope.joins(:author).where(
    "posts.title ILIKE :q OR users.name ILIKE :q",
    q: "%#{query}%"
  ).distinct
end
```

## Filters

| Type | Symbol | Params | Options |
|------|--------|--------|---------|
| Text | `:text` | `query` | `predicate:` |
| Boolean | `:boolean` | `value` | `true_label:`, `false_label:` |
| Date | `:date` | `value` | `predicate:` |
| Date Range | `:date_range` | `from`, `to` | `from_label:`, `to_label:` |
| Select | `:select` | `value` | `choices:`, `multiple:` |
| Association | `:association` | `value` | `class_name:`, `multiple:` |

**Text predicates:** `:eq`, `:not_eq`, `:contains`, `:not_contains`, `:starts_with`, `:ends_with`, `:matches`, `:not_matches`
**Date predicates:** `:eq`, `:not_eq`, `:lt`, `:lteq`, `:gt`, `:gteq`

```ruby
filter :title,        with: :text,        predicate: :contains
filter :active,       with: :boolean
filter :due_date,     with: :date,        predicate: :lt
filter :created_at,   with: :date_range
filter :status,       with: :select,      choices: %w[draft published]
filter :category,     with: :select,      choices: -> { Category.pluck(:name) }
filter :tags,         with: :select,      choices: %w[ruby rails js], multiple: true
filter :category,     with: :association
filter :author,       with: :association, class_name: User
```

**Custom filter class:**

```ruby
class PriceRangeFilter < Plutonium::Query::Filter
  def apply(scope, min: nil, max: nil)
    scope = scope.where("price >= ?", min) if min.present?
    scope = scope.where("price <= ?", max) if max.present?
    scope
  end

  def customize_inputs
    input :min, as: :number
    input :max, as: :number
    field :min, placeholder: "Min price..."
    field :max, placeholder: "Max price..."
  end
end

filter :price, with: PriceRangeFilter
```

## Scopes

Scopes appear as quick filter buttons.

```ruby
scope :published                                  # uses Post.published
scope(:recent) { |s| s.where('created_at > ?', 1.week.ago) }
scope(:mine)   { |s| s.where(author: current_user) }

default_scope :published   # applied on initial load; "All" button clears it
```

### Conditional scopes (`condition:`)

Like `condition:` on actions and fields — define a scope but only **render its button** when a proc is truthy. The scope itself (and its URL) stays live; `condition:` only controls UI visibility.

```ruby
scope :admin_only,   condition: -> { current_user.admin? }
scope :beta_feature, condition: -> { params[:beta] == "1" }
scope :never_shown,  condition: -> { false }  # hides button but URL still works
```

The proc is evaluated against the view context — `current_user`, `params`, `request`, `allowed_to?` are all available directly. There is no `object`/`record` (scopes have no single-record context).

🚨 **`condition:` is NOT authorization.** A hidden scope button still has a live URL. Use `condition:` for UI relevance ("show admins only this tab"). Use the policy's `relation_scope` for "who can see these records at all".

## Sorting

```ruby
sort :title
sort :created_at
sorts :title, :created_at, :view_count   # multiple at once

default_sort :created_at, :desc
default_sort { |scope| scope.order(featured: :desc, created_at: :desc) }
```

## URL Parameters

```
/posts?q[search]=rails
/posts?q[title][query]=widget
/posts?q[status][value]=published
/posts?q[created_at][from]=2024-01-01&q[created_at][to]=2024-12-31
/posts?q[scope]=recent
/posts?q[sort_fields][]=created_at&q[sort_directions][created_at]=desc
```

---

# Part 5 — Actions: Custom and Bulk

## Action Types

| Type flag | Shows In | Use Case |
|-----------|----------|----------|
| `resource_action: true` | Index page | Import, Export, Create |
| `record_action: true` | Show page | Edit, Delete, Archive |
| `collection_record_action: true` | Table rows | Quick per-row actions |
| `bulk_action: true` | Selected records | Bulk operations |
| `hidden: true` | **Nowhere** | Suppresses all four; route + policy stay live (drag gestures, custom JS) |

🚨 **For interactive actions (`interaction:`), all four flags are inferred from the interaction's attributes — don't declare them manually:**

| Interaction declares | Inferred flags |
|---|---|
| `attribute :resource` | `record_action` + `collection_record_action` |
| `attribute :resources` (plural) | `bulk_action` |
| neither | `resource_action` |

User-supplied flags override the inferred ones, but only **opt-out** makes sense for interactive actions — the interaction's `attribute :resource` / `attribute :resources` already fixes the action's semantic shape. Use opt-out to narrow where the button appears:

```ruby
# :resource interaction defaults to record_action + collection_record_action.
# Hide from the per-row menu, keep it on the show page:
action :archive, interaction: ArchiveInteraction, collection_record_action: false

# Hide from the show page, keep the per-row button:
action :preview, interaction: PreviewInteraction, record_action: false
```

Declare flags manually for: simple/navigation actions (no `interaction:`), or opting out of an inferred slot.

## Action Options

```ruby
action :name,
  # Display
  label: "Custom Label",
  description: "What it does",
  icon: Phlex::TablerIcons::Star,
  color: :danger,                   # :primary, :secondary, :danger

  # Visibility (combine as needed)
  resource_action: true,
  record_action: true,
  collection_record_action: true,
  bulk_action: true,

  # Conditional visibility — display-only toggle, NOT authorization (see below).
  # `-> { false }` keeps the route live but hides the button (e.g. API-only).
  condition: -> { params[:beta] == "1" },

  # Never renders anywhere — route + policy stay live. For endpoints reached by
  # a gesture rather than a button (see Hidden Actions below). NOT authorization.
  hidden: true,

  # Grouping
  category: :primary,               # :primary, :secondary, :danger
  position: 50,

  # Behavior
  confirmation: "Are you sure?",
  turbo_frame: "_top",
  route_options: {action: :foo},
  modal: :slideover,                # :slideover / :centered — overrides definition's modal mode
  size:  :lg,                       # :sm / :md / :lg / :xl / :auto / :full — overrides definition's modal size

  # HTML attributes — deep-merged over the framework's, author wins on every key
  link:   {target: "_blank", rel: "noopener"},  # every <a> rendering: toolbar GET link, dropdown items (any method), bulk links, card show link
  button: {data: {analytics: "x"}}              # the button_to <form> wrapper (non-GET toolbar rendering), NOT the inner <button>
```

### HTML Attributes (`link:` / `button:`)

Per-element attribute bags for an action's rendered control. `link:` lands on every anchor the action renders as (dropdown items are anchors even for non-GET actions); `button:` lands on the `button_to` `<form>` element. The author wins on collisions — including `class:` (replaces, no token append) and `turbo_frame`. Pass `data:` as a hash: a scalar `data:` replaces the framework's data wholesale, dropping `turbo_confirm`/`turbo_frame`.

```ruby
action :documentation,
  route_options: {url: "https://docs.example.com"},
  resource_action: true,
  link: {target: "_blank", rel: "noopener noreferrer"}   # open in a new tab
```

Both bags round-trip through `with(...)`: `defined_actions[:edit].with(link: {target: "_blank"})`.

### Conditional Actions (`condition:`)

Like `condition:` on inputs/displays/columns — define an action but render its **button** only when a runtime proc is truthy. The action and its route stay live either way; `condition:` only toggles the UI.

Headline use case: **expose an action's endpoint without a button** — one you call from the API, a webhook, or another service. Hide it with an always-falsy condition; the route still works:

```ruby
# Defined and callable (API / programmatic), but no button anywhere:
action :sync_inventory, interaction: SyncInventoryInteraction, condition: -> { false }

# Per-record display state — object is the row/shown record:
action :reopen, interaction: ReopenInteraction, condition: -> { object.closed? }

# View/request-level toggle (feature flag, beta mode):
action :preview, interaction: PreviewInteraction, condition: -> { params[:beta] == "1" }
```

Inside the proc, `object`/`record` is the contextual record — the row/shown record for **record** and **collection-record** actions, **nil** for **resource** and **bulk** actions (guard with `object&.…` if shared). Every other call delegates to the **view context**: `current_user`, `current_parent`, `params`, `request`, `allowed_to?`, `resource_record!`, etc. `object` is evaluated per row in tables/grids, so per-record show/hide works there.

🚨 **`condition:` is NOT authorization — it only hides the button.** A hidden action still has a live route; anyone with the URL can trigger it. "Who may run this" belongs in the policy:

```ruby
# 🚫 WRONG — does not stop non-admins; the route is live.
action :wipe, interaction: WipeInteraction, condition: -> { current_user.admin? }
# ✅ RIGHT — authorization in the policy, enforced regardless of condition:
def wipe? = current_user.admin?
```

The two compose: an action's button shows only when the policy permits **and** the condition is truthy; execution is gated by the policy alone. Use `object` in `condition:` for per-record *display*; use the policy for per-record *authorization*.

### Hidden Actions (`hidden: true`)

```ruby
action :reposition, hidden: true
```

Renders in **no** toolbar, row dropdown, card, or bulk bar — regardless of visibility flags, policy, or `condition:`. Everything else stays live: the route, the policy predicate (`def reposition?`), and (for `interaction:` actions) the form + permitted-params machinery.

Use it for an endpoint reached by **something other than a button** — a drag gesture, a custom Stimulus controller. The framework uses it for exactly that: `position_on` expands to `action :reposition, hidden: true`, and the kanban drop endpoint is declared the same way.

| | `hidden: true` | `condition: -> { false }` |
|---|---|---|
| Decided | class-load, once | render time, per row/request |
| Says | "never a button" | "a button, just not right now" |

🚨 **`hidden:` is a display gate, NOT an authorization boundary** — same trap as `condition:`. The route is live; authorization belongs in the policy.

`Action#with(...)` — actions are frozen value objects; clone with overrides:

```ruby
def customize_actions
  base = action(:edit)
  replace_action base.with(turbo_frame: nil)
end
```

## Simple Actions (Navigation)

Link to existing routes. The target route MUST already exist.

```ruby
action :documentation,
  label: "Documentation",
  route_options: {url: "https://docs.example.com"},
  icon: Phlex::TablerIcons::Book,
  resource_action: true

action :reports,
  route_options: {action: :reports},
  resource_action: true
```

Named routes are required:

```ruby
resources :posts do
  collection do
    get :reports, as: :reports
  end
end
```

For anything with business logic, use an **Interactive Action** instead.

## Interactive Actions (Interactions)

```ruby
class PostDefinition < ResourceDefinition
  action :publish, interaction: PublishInteraction
  action :archive, interaction: ArchiveInteraction,
    color: :danger, category: :danger, position: 1000,
    confirmation: "Are you sure?"
end
```

⚠️ **An interaction is the button, not the operation.** It's a presentation object — it can only be built with a `view_context`, so anything reachable only through one is reachable only from a Plutonium page. Logic may *start* in `execute` (a one-off with a single caller is fine; don't pre-extract). The **second caller** — a job, an API controller, a rake task, the console — is the trigger to move it onto the **model**, in domain language (`publish!`, `archive!`, `register!`). Not a service layer. Full rule + the validation split: [[plutonium-behavior]] › Part 3 › Where the logic goes.

### Single-record interaction

```ruby
class ArchiveInteraction < ResourceInteraction
  presents label: "Archive",
           icon: Phlex::TablerIcons::Archive,
           description: "Archive this record"

  attribute :resource

  def execute
    resource.archived!
    succeed(resource).with_message("Record archived successfully.")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  rescue => error
    failed("Archive failed. Please try again.")
  end
end
```

### With additional inputs (renders a form)

```ruby
class Company::InviteUserInteraction < Plutonium::Resource::Interaction
  presents label: "Invite User", icon: Phlex::TablerIcons::Mail

  attribute :resource
  attribute :email
  attribute :role

  input :email, as: :email, hint: "User's email address"
  input :role,  as: :select, choices: %w[admin member viewer]

  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :role,  presence: true, inclusion: {in: %w[admin member viewer]}

  def execute
    # Company#invite! creates the row AND sends the mail — a seat-provisioning
    # job needs both, and has no view_context to build an interaction with.
    resource.invite!(email: email, role: role, by: current_user)
    succeed(resource).with_message("Invitation sent to #{email}.")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

### Bulk action

```ruby
class BulkArchiveInteraction < Plutonium::Resource::Interaction
  presents label: "Archive Selected", icon: Phlex::TablerIcons::Archive

  attribute :resources   # plural -> bulk

  def execute
    resources.each(&:archived!)
    succeed(resources).with_message("#{resources.size} records archived.")
  rescue => error
    failed("Bulk archive failed: #{error.message}")
  end
end

# Definition
action :bulk_archive, interaction: BulkArchiveInteraction
# bulk_action: true inferred from `attribute :resources`

# Policy — checked per record; fails the request if ANY record is unauthorized
class PostPolicy < ResourcePolicy
  def bulk_archive? = create?
end
```

The UI only shows bulk action buttons that ALL selected records support. Records are fetched via `current_authorized_scope`.

**Bulk over more than a screenful runs in the request and will time out.** Swap `execute` for `async` and the same interaction dispatches a background run instead, with its declaration and policy unchanged:

```ruby
async do
  on_failure :continue   # :halt (default) | :continue | :transactional
  def perform_on(record) = record.archived!
end
```

The block is the run's class body, not `execute`: it runs later in a job with no controller, so its inputs arrive through `options`. Load [[plutonium-async-interactions]] before building one.

### Resource action (no record)

```ruby
class ImportInteraction < Plutonium::Resource::Interaction
  presents label: "Import CSV", icon: Phlex::TablerIcons::Upload

  # No :resource or :resources -> resource action
  attribute :file
  input :file, as: :file
  validates :file, presence: true

  def execute
    succeed(nil).with_message("Import completed.")
  end
end
```

## Interaction Responses

```ruby
def execute
  succeed(resource).with_message("Done!")
  succeed(resource)
    .with_redirect_response(custom_dashboard_path)
    .with_message("Redirecting...")
  failed(resource.errors)
  failed("Something went wrong")
  failed("Invalid value", :email)
end
```

Redirect is automatic on success. Only use `with_redirect_response` for a non-default destination.

## Default CRUD Actions

```ruby
action :new,     resource_action: true,           position: 10
action :show,    collection_record_action: true,  position: 10
action :edit,    record_action: true,             position: 20
action :destroy, record_action: true,             position: 100, category: :danger
```

## Action Authorization

A custom action only renders if its policy method returns `true`:

```ruby
class PostPolicy < ResourcePolicy
  def publish? = user.admin? || record.author == user
  def archive? = user.admin?
end
```

## Immediate vs Form

- **Immediate** — interaction has only `:resource` (or `:resources`) and no other inputs. Shows an auto-generated browser confirmation (`"#{label}?"`, e.g. `"Archive?"`) on click, then runs. Pass `confirmation: "Custom message"` to override, or `confirmation: false` to skip.
- **Form** — interaction declares extra `attribute`/`input` beyond `:resource`/`:resources`. Renders a modal form first; no auto-confirmation (the form itself is the confirmation step).

## CSV Export (built-in)

Every resource has a streamed CSV export, **disabled by default**. It is not declared
with `action :export_csv` — it's a policy-gated capability with its own split button.
The route (`GET /<resources>/export_csv`) is auto-mounted; the button appears on the
index page once the policy permits it. Enable it by overriding one policy method:

```ruby
class PostPolicy < ResourcePolicy
  def export_csv? = true          # or `index?` to mirror list access
end
```

**Two exports** (split button in the index toolbar, after Filter):
- **Export** (primary) — the current view: selected scope + filters + search (the
  index's `?q`), all matching rows (not just the visible page). File: `posts_<date>.csv`.
- **Export all** (dropdown) — the entire authorized scope, ignoring scope/filters/
  search (`?all=1`). File: `posts_all_<date>.csv`.

Both stream via `find_each` (memory-safe on large tables; primary-key order, so the
file does not preserve the index sort).

- **Columns** = `permitted_attributes_for_export` (defaults to the index columns),
  with the **primary key always first**. Override to tailor:

```ruby
def permitted_attributes_for_export = [:title, :author, :total, :created_at]
```

- **Per-field output** — customize a cell's value and header in the definition with
  the `export` DSL (parallels `display`/`column`):

```ruby
class PostDefinition < ResourceDefinition
  export :author, label: "Author email", &->(post) { post.author.email }
  export :total,                          &->(post) { post.total.format }
end
```

- **Without** an `export` block a column is read off the record: scalars as-is,
  associations as their `display_name_of` label (e.g. `User #5`, not `#<User:…>`). A
  computed/virtual column with no real method **needs** an `export` block (a `label:`-only
  `export` doesn't supply a value) — otherwise the cell renders `<<invalid column>>`.
- **CSV/formula injection** is neutralized automatically (cells starting with `= + - @` or
  tab/CR get a leading `'`).

The button opens in a new tab (so the streamed download bypasses Turbo). Full reference:
`docs/reference/resource/export.md`.

---

## Related Skills

- [[plutonium-behavior]] — controllers, policies (`permitted_attributes_for_*`, action methods), interactions
- [[plutonium-tenancy]] — `associated_with`, `relation_scope`, nested resources
- [[plutonium-ui]] — custom Phlex pages, forms, displays, tables
- [[plutonium-testing]] — testing resources, definitions, policies, interactions
