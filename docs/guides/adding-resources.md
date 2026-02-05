# Adding Resources

This guide covers creating new resources and connecting them to portals.

## Quick Start

```bash
# Generate a resource in the main app
rails g pu:res:scaffold Product name:string 'price:decimal{10,2}' --dest=main_app

# Generate a resource in a feature package
rails g pu:res:scaffold Product name:string 'price:decimal{10,2}' --dest=inventory

# Connect to a portal
rails g pu:res:conn Product --dest=admin_portal
```

## The Resource Generator

### Basic Usage

```bash
rails g pu:res:scaffold ModelName field:type field:type --dest=DESTINATION
```

**Always specify `--dest`** to avoid interactive prompts:
- `--dest=main_app` for resources in the main application
- `--dest=package_name` for resources in a feature package

### Field Types

Format: `name:type:index_type`

| Type | Example | Description |
|------|---------|-------------|
| `string` | `title:string` | Short text (required) |
| `'title:string?'` | `'title:string?'` | Short text (nullable) |
| `text` | `body:text` | Long text |
| `integer` | `quantity:integer` | Whole numbers |
| `decimal` | `'price:decimal{10,2}'` | Decimal with precision |
| `float` | `rating:float` | Floating point |
| `boolean` | `active:boolean` | True/false |
| `date` | `published_on:date` | Date only |
| `datetime` | `published_at:datetime` | Date and time |
| `time` | `starts_at:time` | Time only |
| `json` | `metadata:json` | JSON data |
| `jsonb` | `settings:jsonb` | JSONB (PostgreSQL) |
| `uuid` | `external_id:uuid` | UUID field |

### Nullable Fields

Append `?` to make a field nullable. **Quote fields with special characters**:

```bash
'name:string?'           # Nullable string
'description:text?'      # Nullable text
'published_at:datetime?' # Nullable datetime
```

### Decimal Precision

Use `{precision,scale}` syntax for decimal fields:

```bash
'price:decimal{10,2}'      # precision: 10, scale: 2
'latitude:decimal{11,8}'   # precision: 11, scale: 8
'amount:decimal?{15,2}'    # nullable with precision
```

### Default Values

Use `{default:value}` syntax to set default values:

```bash
'status:string{default:draft}'         # String default
'active:boolean{default:true}'         # Boolean default
'priority:integer{default:0}'          # Integer default
'price:decimal{10,2,default:0}'        # Decimal with precision and default
'category:string?{default:general}'    # Nullable with default
```

### Associations

```bash
# Required belongs_to
user:belongs_to
company:references  # Same as belongs_to

# Nullable belongs_to
'parent:belongs_to?'  # Creates: null: true, optional: true

# Cross-package reference
blogging/post:belongs_to
```

### Indexes

Add index type as the third segment:

```bash
email:string:index   # Regular index
email:string:uniq    # Unique index
```

### Special Types

```bash
password_digest      # has_secure_password
auth_token:token     # has_secure_token (auto unique index)
content:rich_text    # has_rich_text (Action Text)
avatar:attachment    # has_one_attached (Active Storage)
photos:attachments   # has_many_attached
price_cents:integer  # has_cents (money field)
```

### Generator Options

```bash
# Skip model generation (use existing model)
rails g pu:res:scaffold Post --no-model --dest=main_app

# Skip migration generation
rails g pu:res:scaffold Post --no-migration --dest=main_app

# Both (for existing models with Plutonium::Resource::Record)
rails g pu:res:scaffold Post --no-model --no-migration --dest=main_app
```

## Generated Files

### For Main App Resources

```
app/
├── models/post.rb
├── controllers/posts_controller.rb
├── definitions/post_definition.rb
└── policies/post_policy.rb
db/migrate/xxx_create_posts.rb
```

### For Packaged Resources

```
packages/blogging/
├── app/
│   ├── models/blogging/post.rb
│   ├── controllers/blogging/posts_controller.rb
│   ├── definitions/blogging/post_definition.rb
│   └── policies/blogging/post_policy.rb
db/migrate/xxx_create_blogging_posts.rb
```

### Model

```ruby
class Post < ResourceRecord
  include Plutonium::Resource::Record
end
```

### Definition

```ruby
class PostDefinition < ResourceDefinition
  # Fields auto-detected from model
end
```

### Policy

```ruby
class PostPolicy < ResourcePolicy
  def permitted_attributes_for_create
    %i[title content user_id]
  end

  def permitted_attributes_for_read
    %i[title content user_id created_at updated_at]
  end
end
```

## Connecting to Portals

Resources must be connected to a portal to be accessible via the web.

### Using the Generator

```bash
rails g pu:res:conn Post --dest=admin_portal
```

This:
1. Registers the resource in portal routes
2. Creates a portal-specific controller
3. Creates portal-specific policy and definition (if base versions don't exist)

### Connecting Multiple Resources

```bash
rails g pu:res:conn Post Comment Tag --dest=admin_portal
```

### Connecting Namespaced Resources

Use the full class name for packaged resources:

```bash
rails g pu:res:conn Blogging::Post Blogging::Comment --dest=admin_portal
```

### Connecting Singular Resources

For resources that represent a single record per user (e.g., profile):

```bash
rails g pu:res:conn Profile --dest=customer_portal --singular
```

This registers the resource with `singular: true`, generating routes like `/profile` instead of `/profiles/:id`.

### What Gets Generated

```
packages/admin_portal/
├── app/
│   ├── controllers/admin_portal/posts_controller.rb
│   ├── policies/admin_portal/post_policy.rb
│   └── definitions/admin_portal/post_definition.rb
└── config/routes.rb  # Updated with register_resource
```

## Portal-Specific Customization

### Portal Controller

```ruby
# packages/admin_portal/app/controllers/admin_portal/posts_controller.rb
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller

  private

  def build_resource
    super.tap do |post|
      post.user = current_user
    end
  end
end
```

### Portal Definition

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
class AdminPortal::PostDefinition < ::PostDefinition
  # Add admin-only fields
  field :internal_notes

  # Customize existing fields
  field :status, as: :select, collection: %w[draft published archived]
end
```

### Portal Policy

```ruby
# packages/admin_portal/app/policies/admin_portal/post_policy.rb
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy

  # Admins can do everything
  def destroy?
    true
  end

  def permitted_attributes_for_create
    super + [:internal_notes]
  end
end
```

## Multiple Portals

Connect the same resource to multiple portals:

```bash
rails g pu:res:conn Post --dest=admin_portal
rails g pu:res:conn Post --dest=author_portal
```

Each portal can have different customizations.

## From Existing Models

If you have existing Rails models you want to convert to Plutonium resources:

### Option 1: Model already includes Plutonium::Resource::Record

```bash
rails g pu:res:scaffold Post --no-model --no-migration --dest=main_app
```

This generates only the definition, policy, and controller.

### Option 2: Let the generator update the model

```bash
rails g pu:res:scaffold Post --dest=main_app
```

Run without attributes to auto-import fields from the model's content columns.

### Required Model Setup

Your model must include `Plutonium::Resource::Record`:

```ruby
class Post < ApplicationRecord
  include Plutonium::Resource::Record
end
```

## Adding Fields After Creation

### 1. Create Migration

```bash
rails g migration AddStatusToPosts status:string
```

### 2. Update Model (if needed)

```ruby
class Post < ResourceRecord
  validates :status, inclusion: { in: %w[draft published] }
end
```

### 3. Fields Auto-Detected

New columns automatically appear in forms. To customize:

```ruby
# In definition
field :status, as: :select, collection: %w[draft published]
```

## Migration Customizations

Always review and customize generated migrations:

### Inline Indexes (preferred)

```ruby
create_table :posts do |t|
  t.belongs_to :user, null: false, foreign_key: true
  t.string :title, null: false

  t.timestamps

  t.index :title
  t.index [:user_id, :title], unique: true
end
```

### Cascade Delete

```ruby
t.belongs_to :user, null: false, foreign_key: {on_delete: :cascade}
```

### Default Values

Default values can be set directly in the generator using `{default:value}` syntax. For expressions or complex defaults, edit the migration:

```ruby
t.boolean :is_active, default: true
t.datetime :published_at, default: -> { "CURRENT_TIMESTAMP" }
```

## Removing Resources

### Remove from Portal

1. Remove `register_resource` from portal routes
2. Delete portal-specific files in `packages/portal_name/app/`

### Remove Entirely

```bash
# Remove files (main app example)
rm app/models/post.rb
rm app/controllers/posts_controller.rb
rm app/definitions/post_definition.rb
rm app/policies/post_policy.rb

# Create migration to drop table
rails g migration DropPosts
```

## Best Practices

### 1. Always Specify `--dest`
Avoids interactive prompts and makes commands reproducible.

### 2. Quote Special Characters
Fields with `?` or `{}` must be quoted to prevent shell expansion:
```bash
rails g pu:res:scaffold Post 'content:text?' 'price:decimal{10,2}' --dest=main_app
```

### 3. Run Migrations Before Connecting
```bash
rails g pu:res:scaffold Post title:string --dest=main_app
rails db:migrate
rails g pu:res:conn Post --dest=admin_portal
```

### 4. Review Generated Migrations
Add cascade deletes, composite indexes, and default values as needed.

## Troubleshooting

### Resource Not Found

Ensure the resource is connected to the portal with `register_resource`.

### Fields Not Showing

Check that the migration has run and the policy includes the field in `permitted_attributes_for_read`.

### Policy Denying Access

Check the policy's permission methods (`index?`, `show?`, `create?`, etc.) return `true`.

### Connection Generator Fails

Ensure migrations have run - the generator reads model columns to build policy attributes.

## Related

- [Creating Packages](./creating-packages)
- [Nested Resources](./nested-resources)
- [Custom Actions](./custom-actions)
