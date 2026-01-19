---
name: plutonium-model
description: Overview of Plutonium resource models - structure, setup, and best practices
---

# Plutonium Resource Models

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

## Common Patterns

### Archiving (State-Based)

```ruby
class Property < ResourceRecord
  enum :state, archived: 0, active: 1

  scope :active, -> { where(state: :active) }
  scope :archived, -> { where(state: :archived) }

  def archive!
    update!(state: :archived)
  end

  def restore!
    update!(state: :active)
  end
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

### Custom Validation

```ruby
class Contact < ResourceRecord
  validates :contact_type, presence: true

  validate :ensure_contact_provided

  private

  def ensure_contact_provided
    return unless [email, phone, website].all?(&:blank?)
    errors.add(:base, "Please provide at least one contact method")
  end
end
```

### One-to-One Relationships

```ruby
# Parent side
class Tenant < ResourceRecord
  has_one :residential_profile, class_name: "ResidentialTenantProfile"
  has_one :commercial_profile, class_name: "CommercialTenantProfile"
end

# Child side (unique index on foreign key)
class ResidentialTenantProfile < ResourceRecord
  belongs_to :tenant
  # Migration: t.index :tenant_id, unique: true
end
```

### Polymorphic Associations

```ruby
class Comment < ResourceRecord
  belongs_to :commentable, polymorphic: true
end

class Post < ResourceRecord
  has_many :comments, as: :commentable
end

class Photo < ResourceRecord
  has_many :comments, as: :commentable
end
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

## Best Practices

1. **Use enums for state** - `enum :state, archived: 0, active: 1` instead of soft-delete
2. **Compound uniqueness** - Always scope uniqueness to tenant/parent
3. **Organize with comments** - Use section headers for readability
4. **Keep models focused** - Business logic in interactions, not models
5. **Validate at boundaries** - Validate user input, trust internal code
6. **Use scopes** - Define commonly used queries as scopes

## Integration

Models integrate with:
- **Policies** - `resource_field_names` for auto-detection
- **Definitions** - Field introspection for forms/displays
- **Controllers** - `from_path_param` for lookups
- **Query Objects** - Association detection for sorting

## Related Skills

- `plutonium-model-features` - has_cents, associations, scopes, routes
- `plutonium-create-resource` - Scaffold generator for new resources
