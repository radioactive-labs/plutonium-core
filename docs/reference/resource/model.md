# Model

The model layer of a resource. Includes the `Plutonium::Resource::Record` module (via inheritance from `ResourceRecord`) on top of standard `ApplicationRecord`.

## Base class

All resource models inherit from `ResourceRecord` (created by `pu:core:install`):

```ruby
# Main app
class Post < ResourceRecord
end

# Inside a feature package — uses the package's ResourceRecord
module Blogging
  class Post < Blogging::ResourceRecord
  end
end
```

`ResourceRecord` is abstract and inherits from `ApplicationRecord`. Standard ActiveRecord features (associations, validations, scopes, callbacks, attribute macros) all work — Plutonium adds capabilities on top.

## What `Plutonium::Resource::Record` adds

| Module | Purpose | Section |
|---|---|---|
| `HasCents` | Money handling — cents column ↔ decimal accessor | [has_cents](#has-cents) |
| `Routes` | URL parameter customization (slugs, dynamic params) | [URL routing](#url-routing) |
| `Labeling` | `to_label` for human-readable record names | [Labeling](#labeling) |
| `FieldNames` | Field introspection by category | [Field introspection](#field-introspection) |
| `Associations` | Auto-generated SGID accessors on every association | [SGID accessors](#sgid-accessors) |
| `AssociatedWith` | Multi-tenant scoping — `Model.associated_with(entity)` | [Tenancy](/reference/tenancy/entity-scoping) |

## Section layout

Scaffolded models follow a strict ordering. Keep new code in the right section so files stay scannable:

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

## `has_cents`

Stores monetary values as integer cents and exposes a decimal virtual accessor. Use this for money — never store decimals directly.

```ruby
class Product < ResourceRecord
  has_cents :price_cents                    # column: price_cents (integer); accessor: price (decimal)
  has_cents :cost_cents, name: :wholesale   # custom accessor name
  has_cents :tax_cents, rate: 1000          # 3 decimal places (e.g. for fractional currencies)
  has_cents :amount_yen, rate: 1            # currencies with no subunit (JPY)
  has_cents :gbp_cents, unit: "£"           # currency symbol used wherever this renders as currency
  has_cents :multi_cents, unit: :currency_symbol  # per-row: reads record.currency_symbol
  has_cents :points_cents, unit: false      # explicitly no symbol (skips the default)
end

product = Product.new
product.price = 19.99
product.price_cents  # => 1999
product.price        # => 19.99

# Truncates, never rounds
product.price = 10.999
product.price_cents  # => 1099
```

**Currency symbol (`unit:`)** — a `String` is used verbatim (`unit: "£"`); a `Symbol`
names a method read off the record for per-row currencies (`unit: :currency_symbol`
→ `record.currency_symbol`); `false` explicitly renders no symbol. This unit is picked
up automatically anywhere the value renders as currency — show pages, tables, and
grid/kanban cards — so you configure it once on the model. A per-display
`display :price, as: :currency, unit: …` overrides it for that display.

Resolution is `display unit → has_cents unit → config default`, where `nil` means
"not set, keep looking" and `false` means "stop, no symbol". When nothing is set, it
falls back to `Plutonium.configuration.default_currency_unit`, which itself defaults
to the i18n `number.currency.format.unit` *if the locale defines it* (`$` in `en`),
else no symbol:

```ruby
Plutonium.configure do |config|
  config.default_currency_unit = "£"   # app-wide default; false for no symbol; nil → i18n-if-set
end
```

::: danger Use the virtual accessor in policies and definitions
Reference `:price`, NOT `:price_cents`:

```ruby
# Policy
def permitted_attributes_for_create
  %i[name price]   # ✅ virtual name
end

# Definition
field :price, as: :decimal   # ✅ virtual name
```

Generators sometimes emit the `_cents` name in the policy — fix by hand (and verify `has_cents` is declared on the model).
:::

### Options

```ruby
has_cents :field_cents,
  name: :custom_name,     # accessor name (default: field with _cents stripped)
  rate: 100,              # conversion rate (default: 100 for 2 decimal places)
  suffix: "amount"        # suffix for generated name when name pattern matches
```

### Validation propagation

Validations on the cents column automatically mark the virtual accessor invalid too:

```ruby
class Product < ResourceRecord
  has_cents :price_cents
  validates :price_cents, numericality: {greater_than: 0}
end

product = Product.new(price: -10)
product.valid?              # => false
product.errors[:price_cents] # => ["must be greater than 0"]
product.errors[:price]       # => ["is invalid"]
```

The framework adds an `after_validation` hook that copies `:invalid` from `price_cents` → `price` automatically — no manual wiring needed.

### Introspection

```ruby
Product.has_cents_attributes
# => { price_cents: { name: :price, rate: 100 } }

Product.has_cents_attribute?(:price_cents)  # => true
```

## URL routing

### Default

```ruby
post.to_param  # => "1"      (numeric id)
# URL: /posts/1
```

### `path_parameter` — use a stable column

Use a column that's unique and human-readable instead of the numeric id:

```ruby
class User < ResourceRecord
  path_parameter :username
end

user = User.create(username: "john_doe")
user.to_param  # => "john_doe"
# URL: /users/john_doe

User.from_path_param("john_doe")   # finds by username
```

`path_parameter` is a class-level macro (private class method). The column you pass MUST be unique — Plutonium uses it for lookup.

### `dynamic_path_parameter` — SEO-friendly id + slug

Combines the id (for stable lookup) with a slug from another column (for SEO):

```ruby
class Article < ResourceRecord
  dynamic_path_parameter :title
end

article = Article.create(id: 42, title: "Hello World")
article.to_param  # => "42-hello-world"
# URL: /articles/42-hello-world

Article.from_path_param("42-hello-world")  # extracts "42", finds by id
```

The slug is informational — only the id portion is used for lookup, so changing the title doesn't break old URLs.

## Labeling

`to_label` provides a human-readable name for dropdowns, breadcrumbs, and display fallbacks.

### Default resolution

1. Returns `name` if the model has a `name` attribute.
2. Returns `title` if the model has a `title` attribute.
3. Falls back to `"ModelName #id"` (e.g. `"Post #42"`).

```ruby
post = Post.new(title: "Hello World")
post.to_label  # => "Hello World"

post.title = nil
post.to_label  # => "Post #42"
```

### Override

```ruby
class Product < ResourceRecord
  def to_label
    "#{name} (#{sku})"
  end
end
```

## SGID accessors

Every association on a resource model gets Signed Global ID accessors automatically — for secure form submission, API payloads, and hidden fields without exposing database ids.

### Singular associations (`belongs_to`, `has_one`)

```ruby
class Post < ResourceRecord
  belongs_to :user
  has_one :featured_image
end

post.user_sgid               # get SGID
post.user_sgid = "BAh7..."   # set: locates and assigns user from SGID

post.featured_image_sgid
post.featured_image_sgid = "..."
```

### Collection associations (`has_many`, `has_and_belongs_to_many`)

```ruby
class User < ResourceRecord
  has_many :posts
end

user.post_sgids                   # => ["...", "..."]
user.post_sgids = [sgid1, sgid2]  # bulk replace
user.add_post_sgid(sgid)          # append
user.remove_post_sgid(sgid)       # remove
```

These are what `secure_association_tag` uses in forms — see [UI › Forms](/reference/ui/forms).

## Field introspection

```ruby
User.resource_field_names           # all fields suitable for UI
User.content_column_field_names     # database columns
User.belongs_to_association_field_names
User.has_one_association_field_names      # excludes attachments
User.has_many_association_field_names     # excludes attachments
User.has_one_attached_field_names         # ActiveStorage single
User.has_many_attached_field_names        # ActiveStorage multiple
```

Used internally by definitions for auto-detection. You rarely call these directly, but they're useful when writing dynamic UI in `customize_fields` / custom Phlex pages.

Results are cached outside development (so changing the schema in dev hot-reloads correctly).

## Nested attributes introspection

```ruby
Post.all_nested_attributes_options
# => {
#   comments: { allow_destroy: true, limit: 10, macro: :has_many, class: Comment },
#   metadata: { update_only: true, macro: :has_one, class: PostMetadata }
# }
```

Returns the configuration for all associations declared with `accepts_nested_attributes_for`. Used internally by `nested_input` in the definition.

## Multi-tenancy: `associated_with`

`Plutonium::Resource::Record` provides `Model.associated_with(entity)` for multi-tenant queries:

```ruby
Comment.associated_with(post)
# => Comment.where(post: post)
```

Resolution order, association path requirements, three model shapes, and custom scopes are all covered in [Tenancy › Entity scoping](/reference/tenancy/entity-scoping).

## Standard ActiveRecord features

Everything you'd expect works — associations, validations, scopes, callbacks, delegations, `has_rich_text`, `has_secure_token`, `has_one_attached`, etc. Where Plutonium adds twists:

- **Section ordering** is by convention, not enforcement — pick the right slot in the [layout above](#section-layout) so the file stays scannable.
- **Compound uniqueness for tenant-scoped resources:** `validates :code, uniqueness: {scope: :organization_id}` — without the scope, uniqueness leaks across tenants.
- **Keep models thin** — business logic that touches multiple records or has multi-step state changes belongs in [interactions](/reference/behavior/interactions), not model methods.

## Nested resources

Plutonium auto-generates nested routes from `has_many` and `has_one` associations. No model-side change needed beyond the association itself:

```ruby
class Comment < ResourceRecord
  belongs_to :post
end
```

When both `Post` and `Comment` are registered in a portal, `/posts/:post_id/nested_comments` exists automatically. See [Tenancy › Nested resources](/reference/tenancy/nested-resources).

## Table naming in packages

Namespaced models use prefixed tables by default:

```ruby
module Blogging
  class Post < ResourceRecord
    # table: blogging_posts
  end
end
```

Override with `self.table_name = "posts"` if you need a shared table.

## Related

- [Definition](./definition) — controls how the model's fields render
- [Tenancy › Entity scoping](/reference/tenancy/entity-scoping) — `associated_with`, three model shapes
- [App › Generators](/reference/app/generators) — `pu:res:scaffold` field syntax
