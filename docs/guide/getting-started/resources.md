# Working with Resources

::: tip What you'll learn
- How to create and manage resources in Plutonium
- Understanding resource definitions and configurations
- Working with fields, associations, and nested resources
- Implementing resource policies and scoping
- Best practices for resource organization
:::

## Introduction

Resources are the core building blocks of a Plutonium application. A resource represents a model in your application that can be managed through a consistent interface, complete with views, controllers, and policies.

## Creating a Resource

The fastest way to create a resource is using the scaffold generator:

```bash
rails generate pu:res:scaffold Blog user:belongs_to \
  title:string content:text 'published_at:datetime?'
```

This generates several files, including:

::: code-group
```ruby [app/models/blog.rb]
class Blog < ResourceRecord
  belongs_to :user
end
```

```ruby [app/policies/blog_policy.rb]
class BlogPolicy < Plutonium::Resource::Policy
  def create?
    true
  end

  def read?
    true
  end

  def permitted_attributes_for_create
    %i[user title content published_at]
  end

  def permitted_attributes_for_read
    %i[user title content published_at]
  end
end
```

```ruby [app/definitions/blog_definition.rb]
class BlogDefinition < Plutonium::Resource::Definition
end
```
:::

## Resource Definitions

Resource definitions customize how a resource behaves in your application. They define:
- Fields and their types
- Available actions
- Search and filtering capabilities
- Sorting options
- Display configurations

### Basic Field Configuration

::: code-group
```ruby [Simple Fields]
class BlogDefinition < Plutonium::Resource::Definition
  # Basic field definitions
  field :content, as: :text

  # Field with custom display options
  field :published_at,
        as: :datetime,
        hint: "When this post should be published"
end
```

```ruby [Custom Displays]
class BlogDefinition < Plutonium::Resource::Definition
  # Customize how fields are displayed
  display :title, class: "col-span-full"
  display :content, class: "col-span-full" do |f|
    f.text_tag class: "prose dark:prose-invert"
  end

  # Custom column display in tables
  column :published_at, align: :end
end
```
:::

<!--
### Working with Associations

Plutonium makes it easy to work with Rails associations:

```ruby
class BlogDefinition < Plutonium::Resource::Definition
  # Define belongs_to association
  field :user, as: :belongs_to

  # Has-many association with inline creation
  field :comments do |f|
    f.has_many_tag nested: true
  end

  # Configure nested attributes
  define_nested_input :comments,
    inputs: %i[content user],
    limit: 3 do |input|
      input.define_field_input :content,
        type: :text,
        hint: "Keep it constructive"
    end
end
```
-->

### Adding Custom Actions

Beyond CRUD, you can add custom actions to your resources:

```ruby
# app/interactions/blogs/publish.rb
module Blogs
  class Publish < Plutonium::Resource::Interaction
    # Define what this interaction accepts
    attribute :resource, class: Blog
    attribute :publish_date, :date, default: -> { Time.current }

    presents label: "Publish Blog",
             icon: Phlex::TablerIcons::Send,
             description: "Make this blog post public"

    private

    def execute
      if resource.update(
        published_at: publish_date
      )
        succeed(resource)
          .with_message("Blog post published successfully")
          .with_redirect_response(resource)
      else
        failed(resource.errors)
      end
    end
  end
end

# app/definitions/blog_definition.rb
class BlogDefinition < Plutonium::Resource::Definition
  # Register the custom action
  action :publish,
    interaction: Blogs::Publish,
    category: :primary
end
```

### Search and Filtering

Add search and filtering capabilities to your resources:

```ruby
class BlogDefinition < Plutonium::Resource::Definition
  # Enable full-text search
  search do |scope, query|
    scope.where("title ILIKE ? OR content ILIKE ?",
      "%#{query}%", "%#{query}%")
  end

  # Add filters
  filter :published_at,
    with: DateFilter,
    predicate: :gteq

  # Add scopes
  scope :published do |scope|
    scope.where.not(published_at: nil)
  end
  scope :draft do |scope|
    scope.where(published_at: nil)
  end

  # Configure sorting
  sort :title
  sort :published_at
end
```

## Resource Policies

Policies control access to your resources:

```ruby
class BlogPolicy < Plutonium::Resource::Policy
  def permitted_attributes_for_create
    %i[title content state published_at user_id]
  end

  def permitted_associations
    %i[comments]
  end

  def create?
    # Allow logged in users to create blogs
    user.present?
  end

  def update?
    # Users can only edit their own blogs
    record.user_id == user.id
  end

  def publish?
    # Only editors can publish
    user.editor? && record.draft?
  end

  # Scope visible records
  relation_scope do |relation|
    relation = super(relation)
    next relation unless user.admin?

    relation.with_deleted
  end
end
```

## Best Practices

::: tip Resource Organization
1. Keep resource definitions focused and cohesive
2. Use packages to organize related resources
3. Leverage policy scopes for authorization
4. Extract complex logic into interactions
5. Use presenters for view-specific logic
:::

::: warning Common Pitfalls
- Avoid putting business logic in definitions
- Don't bypass policy checks
- Remember to scope resources appropriately
- Test your interactions and policies
:::
