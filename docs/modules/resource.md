---
title: Resource Record Module
---

# Resource Record Module

The Resource Record module (`Plutonium::Resource::Record`) provides enhanced ActiveRecord functionality specifically designed for Plutonium resources. It includes monetary handling, routing enhancements, labeling, field introspection, association management, and entity scoping capabilities.

::: tip Usage
Include this module in your ActiveRecord models to gain access to all Plutonium resource functionality:

```ruby
class Product < ApplicationRecord
  include Plutonium::Resource::Record
end
```

Or inherit from your base resource record class:

```ruby
class Product < MyApp::ResourceRecord
  # MyApp::ResourceRecord includes Plutonium::Resource::Record
end
```
:::

## Included Modules

The Resource Record module automatically includes six specialized modules:

1. **Plutonium::Models::HasCents** - Monetary value handling
2. **Plutonium::Resource::Record::Routes** - URL parameter and routing enhancements
3. **Plutonium::Resource::Record::Labeling** - Human-readable record labels
4. **Plutonium::Resource::Record::FieldNames** - Field introspection and categorization
5. **Plutonium::Resource::Record::Associations** - Enhanced association methods with SGID support
6. **Plutonium::Resource::Record::AssociatedWith** - Entity scoping and association queries

---

## Monetary Handling (HasCents)

The `HasCents` module provides sophisticated monetary value handling, storing amounts as integers (cents) while exposing decimal interfaces for easy manipulation.

### Basic Usage

```ruby
class Product < ApplicationRecord
  include Plutonium::Resource::Record

  # Define monetary fields
  has_cents :price_cents                    # Creates price getter/setter
  has_cents :cost_cents, name: :wholesale   # Custom name
  has_cents :tax_cents, rate: 1000         # Custom rate (1000 = 3 decimal places)
  has_cents :total_cents, suffix: "amount" # Custom suffix
end

# Usage
product = Product.new
product.price = 19.99
product.price_cents  # => 1999
product.price        # => 19.99

product.wholesale = 12.50
product.cost_cents   # => 1250
```

### Advanced Features

**Precision and Truncation**
```ruby
product.price = 10.999   # Truncates, doesn't round
product.price_cents      # => 1099
product.price           # => 10.99
```

**Custom Conversion Rates**
```ruby
class Product < ApplicationRecord
  has_cents :weight_cents, name: :weight, rate: 1000  # 3 decimal places
  has_cents :quantity_cents, name: :quantity, rate: 1 # Whole numbers only
end

product.weight = 1.234
product.weight_cents  # => 1234

product.quantity = 5
product.quantity_cents # => 5
```

**Validation Integration**
```ruby
class Product < ApplicationRecord
  has_cents :price_cents

  validates :price_cents, numericality: { greater_than: 0 }
end

product = Product.new(price: -10)
product.valid?  # => false
product.errors[:price_cents]  # => ["must be greater than 0"]
product.errors[:price]        # => ["is invalid"]
```

### Class Methods

**Introspection**
```ruby
Product.has_cents_attributes
# => {
#   price_cents: { name: :price, rate: 100 },
#   cost_cents: { name: :wholesale, rate: 100 }
# }

Product.has_cents_attribute?(:price_cents)  # => true
Product.has_cents_attribute?(:name)         # => false
```

---

## Routing Enhancements

The Routes module provides flexible URL parameter handling and association route discovery.

### URL Parameters

**Default Behavior**
```ruby
# Uses :id by default
user = User.find(1)
user.to_param  # => "1"
```

**Custom Path Parameters**
```ruby
class User < ApplicationRecord
  include Plutonium::Resource::Record

  private

  def path_parameter(param_name)
    # Uses specified field as URL parameter
    path_parameter :username
  end
end

user = User.create(username: "john_doe")
user.to_param  # => "john_doe"
# URLs become /users/john_doe instead of /users/1
```

**Dynamic Path Parameters**
```ruby
class Article < ApplicationRecord
  include Plutonium::Resource::Record

  private

  def dynamic_path_parameter(param_name)
    # Creates SEO-friendly URLs with ID prefix
    dynamic_path_parameter :title
  end
end

article = Article.create(title: "My Great Article")
article.to_param  # => "1-my-great-article"
# URLs become /articles/1-my-great-article
```

### Association Route Discovery

**Has Many Routes**
```ruby
class User < ApplicationRecord
  has_many :posts
  has_many :comments
end

User.has_many_association_routes
# => ["posts", "comments"]
```

**Nested Attributes Detection**
```ruby
class User < ApplicationRecord
  has_many :posts
  accepts_nested_attributes_for :posts
end

User.all_nested_attributes_options
# => {
#   posts: {
#     allow_destroy: false,
#     update_only: false,
#     macro: :has_many,
#     class: Post
#   }
# }
```

### Scopes

**Path Parameter Lookup**
```ruby
# Automatically included scope for parameter-based lookups
User.from_path_param("john_doe")  # Uses configured parameter field
Article.from_path_param("1-my-great-article")  # Extracts ID from dynamic parameter
```

---

## Record Labeling

The Labeling module provides intelligent human-readable labels for records.

### Automatic Label Generation

```ruby
class User < ApplicationRecord
  include Plutonium::Resource::Record

  # Will try :name first, then :title, then fallback
end

user = User.new(name: "John Doe")
user.to_label  # => "John Doe"

user_without_name = User.create(id: 1)
user_without_name.to_label  # => "User #1"
```

### Label Priority

The `to_label` method checks fields in this order:
1. `:name` attribute (if present and not blank)
2. `:title` attribute (if present and not blank)
3. Fallback: `"#{model_name.human} ##{to_param}"`

### Custom Labels

```ruby
class Product < ApplicationRecord
  include Plutonium::Resource::Record

  # Override to_label for custom behavior
  def to_label
    "#{name} (#{sku})"
  end
end

product = Product.new(name: "Widget", sku: "W123")
product.to_label  # => "Widget (W123)"
```

---

## Field Introspection

The FieldNames module provides comprehensive field categorization and introspection capabilities.

### Field Categories

**Resource Fields**
```ruby
class User < ApplicationRecord
  include Plutonium::Resource::Record
end

User.resource_field_names
# => [:id, :name, :email, :created_at, :updated_at, ...]
```

**Association Fields**
```ruby
class Post < ApplicationRecord
  belongs_to :user
  has_many :comments
  has_one :featured_image
end

Post.belongs_to_association_field_names  # => [:user]
Post.has_one_association_field_names     # => [:featured_image]
Post.has_many_association_field_names    # => [:comments]
```

**Attachment Fields**
```ruby
class User < ApplicationRecord
  has_one_attached :avatar
  has_many_attached :documents
end

User.has_one_attached_field_names   # => [:avatar]
User.has_many_attached_field_names  # => [:documents]
```

### Field Filtering

The module automatically filters out Rails internal associations:
- `*_attachment` and `*_blob` associations are excluded from has_one results
- `*_attachments` and `*_blobs` associations are excluded from has_many results

---

## Enhanced Associations

The Associations module enhances standard Rails associations with Signed Global ID (SGID) support for secure serialization.

### SGID Methods

**Singular Associations (belongs_to, has_one)**
```ruby
class Post < ApplicationRecord
  include Plutonium::Resource::Record
  belongs_to :user
  has_one :featured_image
end

post = Post.first

# SGID getters
post.user_sgid           # => "BAh7CEkiCG..."
post.featured_image_sgid # => "BAh7CEkiCG..."

# SGID setters
post.user_sgid = "BAh7CEkiCG..."  # Finds and assigns user
post.featured_image_sgid = "BAh7CEkiCG..."
```

**Collection Associations (has_many, has_and_belongs_to_many)**
```ruby
class User < ApplicationRecord
  include Plutonium::Resource::Record
  has_many :posts
  has_and_belongs_to_many :roles
end

user = User.first

# Collection SGID methods
user.post_sgids  # => ["BAh7CEkiCG...", "BAh7CEkiCG..."]
user.role_sgids  # => ["BAh7CEkiCG...", "BAh7CEkiCG..."]

# Collection SGID assignment
user.post_sgids = ["BAh7CEkiCG...", "BAh7CEkiCG..."]
user.role_sgids = ["BAh7CEkiCG...", "BAh7CEkiCG..."]

# Individual manipulation
user.add_post_sgid("BAh7CEkiCG...")     # Adds post to collection
user.remove_post_sgid("BAh7CEkiCG...")  # Removes post from collection
```

### Security Benefits

SGID methods provide:
- **Secure serialization**: Records can be safely serialized without exposing internal IDs

---

## Entity Scoping (AssociatedWith)

The AssociatedWith module provides sophisticated entity scoping for multi-tenant applications and complex association queries.

### Basic Usage

```ruby
class Document < ApplicationRecord
  include Plutonium::Resource::Record
  belongs_to :user
end

class User < ApplicationRecord
  has_many :documents
end

# Find all documents associated with a specific user
user = User.first
Document.associated_with(user)
# Equivalent to: Document.where(user: user)
```

### Automatic Association Detection

The module automatically detects associations in both directions:

**Direct Association (Preferred)**
```ruby
class Comment < ApplicationRecord
  belongs_to :post  # Direct association
end

# Automatically uses the direct association
Comment.associated_with(post)  # => Comment.where(post: post)
```

**Reverse Association (With Performance Warning)**
```ruby
class Post < ApplicationRecord
  has_many :comments  # Reverse association
end

# Uses reverse association with performance warning
Comment.associated_with(post)
# Warning: Using indirect association from Post to Comment
# via 'comments'. This may result in poor query performance...
```

### Custom Scopes

For optimal performance, where a direct association is not possible, define custom scopes:

```ruby
class Comment < ApplicationRecord
  include Plutonium::Resource::Record

  # Custom scope for better performance
  scope :associated_with_post, ->(post) { where(post_id: post.id) }
end

# Automatically uses the custom scope
Comment.associated_with(post)  # Uses :associated_with_post scope
```

### Association Query Types

**Belongs To**
```ruby
class Comment < ApplicationRecord
  belongs_to :post
end

Comment.associated_with(post)
# Generates: Comment.where(post: post)
```

**Has One**
```ruby
class Profile < ApplicationRecord
  has_one :user
end

Profile.associated_with(user)
# Generates: Profile.joins(:user).where(user: {id: user.id})
```

**Has Many**
```ruby
class Post < ApplicationRecord
  has_many :comments
end

# When finding posts associated with a comment
Post.associated_with(comment)
# Generates: Post.joins(:comments).where(comments: {id: comment.id})
```

### Error Handling

When associations cannot be resolved:

```ruby
class UnrelatedModel < ApplicationRecord
  include Plutonium::Resource::Record
end

UnrelatedModel.associated_with(user)
# Raises: Could not resolve the association between 'UnrelatedModel' and 'User'
#
# Define:
#  1. the associations between the models
#  2. a named scope on UnrelatedModel e.g.
#
# scope :associated_with_user, ->(user) { do_something_here }
```

---

## Generator Integration

The Resource Record module integrates seamlessly with Plutonium generators:

### Model Generation

```bash
# Generate a model with monetary fields
rails generate pu:res:model Product name:string price_cents:integer

# Generated model includes has_cents automatically
class Product < MyApp::ResourceRecord
  has_cents :price_cents
  validates :name, presence: true
end
```

### Automatic Field Detection

Generators automatically detect and configure:
- `*_cents` fields get `has_cents` declarations
- Reference fields get `belongs_to` associations
- Required fields get presence validations

---

## Best Practices

### Monetary Fields

```ruby
# ✅ Good: Use descriptive names
has_cents :price_cents
has_cents :shipping_cost_cents, name: :shipping_cost

# ❌ Avoid: Generic names
has_cents :amount_cents  # What kind of amount?
```

### Custom Path Parameters

```ruby
# ✅ Good: Use stable, unique fields
class User < ApplicationRecord
  private

  def path_parameter(param_name)
    path_parameter :username  # Stable and unique
  end
end

# ❌ Avoid: Changeable fields
class User < ApplicationRecord
  private

  def dynamic_path_parameter(param_name)
    dynamic_path_parameter :name  # Can change, breaks bookmarks
  end
end
```

### Entity Scoping

```ruby
# ✅ Good: Define custom scopes for complex queries
class Order < ApplicationRecord
  scope :associated_with_customer, ->(customer) do
    joins(:customer).where(customers: { id: customer.id })
  end
end

# ✅ Good: Use direct associations when possible
class OrderItem < ApplicationRecord
  belongs_to :order
  # associated_with will automatically use the direct association
end
```

### Field Introspection

```ruby
# ✅ Good: Use field introspection in dynamic code
def build_form_fields
  resource_class.resource_field_names.each do |field|
    # Build form field dynamically
  end
end

# ✅ Good: Cache results in production
def expensive_field_analysis
  Rails.cache.fetch("#{model_name}_field_analysis", expires_in: 1.hour) do
    analyze_fields(resource_field_names)
  end
end
```

---

## Performance Considerations

### Field Introspection Caching

Field introspection methods are automatically cached in non-local environments:

```ruby
# Cached in production/staging
User.resource_field_names
User.has_many_association_field_names

# Always fresh in development
Rails.env.local?  # => true, no caching
```

### Association Query Optimization

```ruby
# ✅ Efficient: Direct association
Comment.associated_with(post)  # Uses WHERE clause

# ⚠️ Less efficient: Reverse association
Post.associated_with(comment)  # Uses JOIN + WHERE

# ✅ Optimal: Custom scope
scope :associated_with_comment, ->(comment) do
  where(id: comment.post_id)  # Direct ID lookup
end
```

### SGID Performance

```ruby
# ✅ Efficient: Batch operations
user.post_sgids = sgid_array  # Single assignment

# ❌ Inefficient: Individual operations
sgid_array.each { |sgid| user.add_post_sgid(sgid) }  # Multiple queries
```

The Resource Record module provides a comprehensive foundation for building robust, feature-rich ActiveRecord models within the Plutonium framework, handling everything from monetary values to complex association queries with performance and security in mind.
