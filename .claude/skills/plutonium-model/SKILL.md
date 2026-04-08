---
name: plutonium-model
description: Use BEFORE editing a Plutonium resource model, adding associations, has_cents, SGID, or routing helpers. For tenancy / associated_with / relation_scope, also load plutonium-entity-scoping.
---

# Plutonium Resource Models

## 🚨 Critical (read first)
- **Use `pu:res:scaffold`.** Never hand-write resource model files — the scaffold sets up `Plutonium::Resource::Record`, associations, and the expected section layout.
- **Declare associations for the entity.** For multi-tenant apps, add `belongs_to`, `has_one :through`, or an `associated_with_<entity>` scope so `associated_with` can resolve. Fix the model, not the policy.
- **Compound uniqueness** — in multi-tenant models, scope unique constraints to the tenant FK (`uniqueness: {scope: :organization_id}`), or you leak across tenants.
- **Keep business logic out of the model.** Use interactions for multi-step ops, policies for authorization.
- **Related skills:** `plutonium-entity-scoping` (tenancy mechanics), `plutonium-create-resource` (scaffold), `plutonium-definition` (UI), `plutonium-policy` (authorization).

## Quick checklist

Adding/editing a Plutonium model:

1. Use `pu:res:scaffold` for new models; include `Plutonium::Resource::Record` on existing ones.
2. Place associations/enums/validations in the right section (enums → belongs_to → has_one → has_many → scopes → validations → callbacks).
3. For monetary fields, use `has_cents :field_cents`.
4. For multi-tenancy, declare an association path to the entity (`belongs_to`, `has_one :through`, or a custom `associated_with_<entity>` scope).
5. Add compound uniqueness scoped to the tenant FK.
6. For SEO URLs, override `path_parameter` or `dynamic_path_parameter`.
7. Override `to_label` if `:name`/`:title` isn't meaningful.
8. Verify with `rails runner "puts Model.first.associated_with(entity).count"`.

**Always use generators to create models** - never create model files manually:
```bash
rails g pu:res:scaffold Post title:string content:text --dest=main_app
```
See `plutonium-create-resource` for full field type syntax and generator options.

A model becomes a Plutonium resource by including `Plutonium::Resource::Record`. This provides enhanced ActiveRecord functionality for routing, labeling, field introspection, associations, and monetary handling.

## Setup

### Standard Setup

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  include Plutonium::Resource::Record
  primary_abstract_class
end

# app/models/resource_record.rb (optional abstract class)
class ResourceRecord < ApplicationRecord
  self.abstract_class = true
end

# app/models/property.rb
class Property < ResourceRecord
  # Now has access to all Plutonium features
end
```

### What's Included

`Plutonium::Resource::Record` includes six modules:

| Module | Purpose |
|--------|---------|
| `HasCents` | Monetary value handling (cents → decimal) |
| `Routes` | URL parameters, path customization |
| `Labeling` | Human-readable `to_label` method |
| `FieldNames` | Field introspection and categorization |
| `Associations` | SGID support for secure serialization |
| `AssociatedWith` | Entity scoping for multi-tenant apps |

## Model Structure

Follow the template structure (comment markers indicate where to add code):

```ruby
class Property < ResourceRecord
  # add concerns above.

  TYPES = {apartment: "Apartment", house: "House"}.freeze
  # add constants above.

  enum :state, archived: 0, active: 1
  enum :property_class, residential: 0, commercial: 1
  # add enums above.

  has_cents :market_value_cents
  # add model configurations above.

  belongs_to :company
  # add belongs_to associations above.

  has_one :address
  # add has_one associations above.

  has_many :units
  has_many :amenities, class_name: "PropertyAmenity"
  # add has_many associations above.

  has_one_attached :photo
  has_many_attached :documents
  # add attachments above.

  scope :active, -> { where(state: :active) }
  scope :by_company, ->(company) { where(company: company) }
  # add scopes above.

  validates :name, presence: true
  validates :property_code, presence: true, uniqueness: {scope: :company_id}
  # add validations above.

  before_validation :generate_code, on: :create
  # add callbacks above.

  delegate :name, to: :company, prefix: true
  # add delegations above.

  has_rich_text :description
  # add misc attribute macros above.

  def full_address
    address&.to_s
  end

  # add methods above. add private methods below.

  private

  def generate_code
    self.property_code ||= SecureRandom.hex(4).upcase
  end
end
```

### Section Order

1. **Concerns** - `include` statements
2. **Constants** - `TYPES = {...}.freeze`, etc.
3. **Enums** - `enum :state, ...`
4. **Model configurations** - `has_cents`
5. **belongs_to associations**
6. **has_one associations**
7. **has_many associations**
8. **Attachments** - `has_one_attached`, `has_many_attached`
9. **Scopes**
10. **Validations**
11. **Callbacks**
12. **Delegations**
13. **Misc attribute macros** - `has_rich_text`, `has_secure_token`, `has_secure_password`
14. **Methods** - Public methods above, private methods below

## Monetary Handling (has_cents)

Store monetary values as integers (cents) while exposing decimal interfaces.

### Basic Usage

```ruby
class Product < ResourceRecord
  has_cents :price_cents                    # Creates price getter/setter
  has_cents :cost_cents, name: :wholesale   # Custom accessor name
  has_cents :tax_cents, rate: 1000          # 3 decimal places
  has_cents :quantity_cents, rate: 1        # Whole numbers only
end

product = Product.new
product.price = 19.99
product.price_cents  # => 1999
product.price        # => 19.99

# Truncates (doesn't round)
product.price = 10.999
product.price_cents  # => 1099
```

### Options

```ruby
has_cents :field_cents,
  name: :custom_name,    # Accessor name (default: field without _cents)
  rate: 100,             # Conversion rate (default: 100)
  suffix: "amount"       # Suffix for generated name (default: "amount")
```

### Using `has_cents` fields in policies and definitions

**Always reference the virtual accessor (`:price`), never the underlying column (`:price_cents`).**

```ruby
# Model
class Product < ResourceRecord
  has_cents :price_cents   # exposes virtual :price
end

# ✅ Policy — use the virtual name
class ProductPolicy < ResourcePolicy
  def permitted_attributes_for_create
    %i[name price]   # NOT :price_cents
  end
end

# ✅ Definition — use the virtual name
class ProductDefinition < ResourceDefinition
  field :price, as: :decimal
end
```

The virtual accessor handles form input, validation, and display as a decimal. Using `:price_cents` directly in a policy or definition forces users to enter integer cents and bypasses the conversion. Generators sometimes emit the `_cents` name in the policy — fix it by hand if you see it (and add `has_cents` if it's missing from the model).

### Validation

```ruby
class Product < ResourceRecord
  has_cents :price_cents

  # Validate the cents field
  validates :price_cents, numericality: {greater_than: 0}
end

product = Product.new(price: -10)
product.valid?  # => false
product.errors[:price_cents]  # => ["must be greater than 0"]
product.errors[:price]        # => ["is invalid"] (propagated)
```

### Introspection

```ruby
Product.has_cents_attributes
# => {price_cents: {name: :price, rate: 100}, ...}

Product.has_cents_attribute?(:price_cents)  # => true
```

## Association SGID Support

All associations get Signed Global ID (SGID) methods for secure serialization.

### Singular Associations (belongs_to, has_one)

```ruby
class Post < ResourceRecord
  belongs_to :user
  has_one :featured_image
end

post = Post.first

# Get SGID
post.user_sgid           # => "BAh7CEkiCG..."
post.featured_image_sgid # => "BAh7CEkiCG..."

# Set by SGID (finds and assigns)
post.user_sgid = "BAh7CEkiCG..."
post.featured_image_sgid = "BAh7CEkiCG..."
```

### Collection Associations (has_many, has_and_belongs_to_many)

```ruby
class User < ResourceRecord
  has_many :posts
  has_and_belongs_to_many :roles
end

user = User.first

# Get SGIDs
user.post_sgids  # => ["BAh7CEkiCG...", "BAh7CEkiCG..."]
user.role_sgids  # => ["BAh7CEkiCG...", "BAh7CEkiCG..."]

# Bulk assignment
user.post_sgids = ["BAh7CEkiCG...", ...]

# Individual manipulation
user.add_post_sgid("BAh7CEkiCG...")     # Add to collection
user.remove_post_sgid("BAh7CEkiCG...")  # Remove from collection
```

## Entity Scoping (associated_with)

`Plutonium::Resource::Record` provides `Model.associated_with(entity)` for multi-tenant queries. It resolves via a custom `associated_with_<entity>` scope, a direct `belongs_to`, or an auto-detected `has_one :through` chain.

Quick example:

```ruby
class Comment < ResourceRecord
  belongs_to :post
end

Comment.associated_with(post)  # => Comment.where(post: post)
```

> **For entity scoping details — the three model shapes (direct child, join table, grandchild), `has_one :through` patterns, custom scopes, `default_relation_scope`, and how it fits with policies and portals — see the [plutonium-entity-scoping](../plutonium-entity-scoping/SKILL.md) skill. It is the single source of truth.**

## URL Routing

### Default Behavior

```ruby
user = User.find(1)
user.to_param  # => "1"
```

### Custom Path Parameters

Use a stable, unique field instead of ID:

```ruby
class User < ResourceRecord
  private

  def path_parameter(param_name)
    :username  # Must be unique
  end
end

user = User.create(username: "john_doe")
user.to_param  # => "john_doe"
# URLs: /users/john_doe
```

### Dynamic Path Parameters (SEO-friendly)

Include ID prefix for uniqueness with human-readable suffix:

```ruby
class Article < ResourceRecord
  private

  def dynamic_path_parameter(param_name)
    :title
  end
end

article = Article.create(id: 1, title: "My Great Article")
article.to_param  # => "1-my-great-article"
# URLs: /articles/1-my-great-article
```

### Path Parameter Lookup

```ruby
User.from_path_param("john_doe")
Article.from_path_param("1-my-great-article")  # Extracts ID
```

## Labeling

The `to_label` method provides human-readable record labels:

```ruby
# Automatic - checks :name, then :title, then fallback
user = User.new(name: "John Doe")
user.to_label  # => "John Doe"

user = User.create(id: 1)
user.to_label  # => "User #1"

# Custom override
class Product < ResourceRecord
  def to_label
    "#{name} (#{sku})"
  end
end
```

## Field Introspection

Access field information programmatically:

```ruby
# All resource fields
User.resource_field_names
# => [:id, :name, :email, :company, :avatar, ...]

# By category
User.content_column_field_names           # Database columns
User.belongs_to_association_field_names   # belongs_to associations
User.has_one_association_field_names      # has_one associations
User.has_many_association_field_names     # has_many associations
User.has_one_attached_field_names         # Active Storage single
User.has_many_attached_field_names        # Active Storage multiple
```

## Common Patterns

### Archiving (State-Based)

```ruby
class Property < ResourceRecord
  enum :state, archived: 0, active: 1

  scope :active, -> { where(state: :active) }
  scope :archived, -> { where(state: :archived) }
end
```

### Multi-Tenant Scoping

```ruby
class Property < ResourceRecord
  belongs_to :company

  # Compound uniqueness for multi-tenant
  validates :property_code, uniqueness: {scope: :company_id}

  # Custom scope for entity scoping
  scope :associated_with_company, ->(company) { where(company: company) }
end
```

## Performance Tips

```ruby
# Efficient: Direct belongs_to
Comment.associated_with(post)  # Simple WHERE

# Less efficient: Reverse has_many (logs warning)
Post.associated_with(comment)  # JOIN required

# Optimal: Custom scope when direct isn't possible
scope :associated_with_user, ->(user) { where(user_id: user.id) }

# SGID: Batch assignment over individual adds
user.post_sgids = sgid_array  # Single operation
```

## Best Practices

1. **Use enums for state** - `enum :state, archived: 0, active: 1` instead of soft-delete
2. **Compound uniqueness** - Always scope uniqueness to tenant/parent
3. **Organize with comments** - Use section headers for readability
4. **Keep models focused** - Business logic in interactions, not models
5. **Validate at boundaries** - Validate user input, trust internal code
6. **Use scopes** - Define commonly used queries as scopes

## Related Skills

- `plutonium-create-resource` - Scaffold generator for new resources
- `plutonium-definition` - Definition overview, fields, inputs, displays
