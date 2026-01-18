# Model Features

Features provided by `Plutonium::Resource::Record`.

## has_cents

Store monetary values as integers (cents) while exposing decimal accessors.

```ruby
class Product < ResourceRecord
  # Column: price_cents (integer)
  # Generates: price (decimal accessor)
  has_cents :price_cents
end
```

### Usage

```ruby
product = Product.new
product.price = 19.99
product.price_cents  # => 1999

product.price_cents = 2500
product.price  # => 25.0
```

### Options

```ruby
class Order < ResourceRecord
  # Default: rate 100 (cents to dollars)
  has_cents :subtotal_cents

  # Custom name for the accessor
  has_cents :cost_cents, name: :wholesale_price
  # cost_cents column, wholesale_price accessor

  # Yen or other currencies without subunits (rate: 1)
  has_cents :price_yen, name: :price_jpy, rate: 1

  # Higher precision (e.g., 1000 units per dollar)
  has_cents :amount_cents, rate: 1000

  # Custom suffix when name matches column pattern
  has_cents :total_cents, suffix: "value"
  # Generates: total_value accessor
end
```

### Validation Inheritance

Validations on the cents column propagate to the decimal accessor:

```ruby
class Product < ResourceRecord
  has_cents :price_cents
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
end

product = Product.new(price: -10)
product.valid?              # => false
product.errors[:price_cents] # => ["must be greater than or equal to 0"]
product.errors[:price]       # => ["is invalid"]
```

### Reflection

```ruby
Product.has_cents_attributes
# => { price_cents: { name: :price, rate: 100 } }

Product.has_cents_attribute?(:price_cents)  # => true
Product.has_cents_attribute?(:name)         # => false
```

## Labeling

The `to_label` method provides a human-readable representation for dropdowns and displays:

```ruby
post.to_label  # => "My Post Title"
user.to_label  # => "John Doe"
```

### Resolution Order

1. Returns `name` attribute if present
2. Returns `title` attribute if present
3. Falls back to `"ModelName #id"`

```ruby
class Post < ResourceRecord
  # Has title column
end

post = Post.new(title: "Hello World")
post.to_label  # => "Hello World"

post.title = nil
post.to_label  # => "Post #123"
```

## Route Parameters

Customize how records appear in URLs.

### Static Parameter

Use a specific column for URLs:

```ruby
class Post < ResourceRecord
  path_parameter :slug
end
```

```ruby
post = Post.create(slug: "hello-world")
post.to_param  # => "hello-world"

# URL: /posts/hello-world
Post.from_path_param("hello-world")  # Finds by slug
```

### Dynamic Parameter

Combine ID with a readable slug:

```ruby
class Post < ResourceRecord
  dynamic_path_parameter :title
end
```

```ruby
post = Post.create(id: 42, title: "Hello World")
post.to_param  # => "42-hello-world"

# URL: /posts/42-hello-world
Post.from_path_param("42-hello-world")  # Extracts ID, finds by id
```

## Secure Association SGIDs

Associations automatically get Signed Global ID accessors for secure form handling.

### Singular Associations (belongs_to, has_one)

```ruby
class Post < ResourceRecord
  belongs_to :author
end
```

Generates:

```ruby
post.author_sgid       # => SignedGlobalID for the author
post.author_sgid = sgid  # Locates and assigns author from SGID
```

### Collection Associations (has_many)

```ruby
class Post < ResourceRecord
  has_many :tags
end
```

Generates:

```ruby
post.tag_sgids                    # => Array of SignedGlobalIDs
post.tag_sgids = [sgid1, sgid2]   # Locates and assigns tags from SGIDs
post.add_tag_sgid(sgid)           # Add a single tag by SGID
post.remove_tag_sgid(sgid)        # Remove a single tag by SGID
```

### Use Case

These methods enable secure association inputs in forms without exposing database IDs:

```ruby
# In form
f.secure_association_tag  # Uses SGIDs instead of IDs
```

## associated_with Scope

Finds records associated with a given parent. Used internally for nested resource scoping.

```ruby
Comment.associated_with(post)  # Comments belonging to post
```

### Resolution Order

1. Checks for custom scope: `associated_with_#{model_name}`
2. Finds direct association from self to record
3. Finds reverse association from record to self (with performance warning)
4. Raises error with helpful message

### Custom Scope

For complex relationships, define a named scope:

```ruby
class Comment < ResourceRecord
  # Comments belong to posts, which belong to organizations
  scope :associated_with_organization, ->(org) {
    joins(:post).where(posts: { organization_id: org.id })
  }
end
```

## Field Name Introspection

Class methods for discovering model fields by type:

```ruby
Post.resource_field_names           # All fields suitable for forms/displays
Post.content_column_field_names     # Database content columns
Post.belongs_to_association_field_names  # belongs_to associations
Post.has_one_association_field_names     # has_one associations (excluding attachments)
Post.has_many_association_field_names    # has_many associations (excluding attachments)
Post.has_one_attached_field_names        # Single file attachments
Post.has_many_attached_field_names       # Multiple file attachments
```

These methods are cached in non-local environments for performance.

## Nested Attributes Introspection

```ruby
Post.all_nested_attributes_options
# => {
#   comments: { allow_destroy: true, limit: 10, macro: :has_many, class: Comment },
#   metadata: { update_only: true, macro: :has_one, class: PostMetadata }
# }
```

Returns configuration for all associations with `accepts_nested_attributes_for`.

## Related

- [Model Reference](./index)
- [Nested Resources Guide](/guides/nested-resources)
