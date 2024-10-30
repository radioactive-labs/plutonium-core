# What is Plutonium?

Plutonium extends Rails with powerful tools, patterns and conventions to accelerate application development. It acts as a higher-level abstraction on top of Rails, providing ready-to-use solutions for common application needs while preserving Rails' flexibility and elegance.

## Core Concepts

Plutonium builds on several key concepts that enhance Rails development:

### Resource-Oriented Architecture
Plutonium treats your application as a collection of resources, providing conventions and tools to rapidly build CRUD interfaces and business logic around these resources.

### Modular Design
Using Rails engines, Plutonium enables clean separation of concerns through packages. Each package can contain its own resources, controllers, views, and business logic.

### Convention over Configuration
Like Rails itself, Plutonium provides sensible defaults while allowing customization when needed. This reduces boilerplate while maintaining flexibility.

### Progressive Enhancement
Built on modern web technologies like Hotwire, Plutonium delivers rich interactivity without sacrificing the simplicity of server-rendered HTML.

## Use Cases

::: details Administrative Interfaces
- Rapidly generate and customize admin panels
- Configurable resource views and actions
- Advanced search, filtering, and resource operations
:::

::: details Business Applications
- Quick implementation of business workflows
- Form-heavy applications with complex validation
- Resource management systems
- Multi-tenant applications
:::

::: details Content Management Systems
- Resource-based content organization
- Media management
- Content workflow automation
:::

## Why Plutonium?

### Accelerated Development
- Pre-built components for common functionality
- Generators for boilerplate code
- Convention-based resource handling
- Integrated authentication and authorization

### Maintainable Architecture
- Clear separation of concerns through packages
- Consistent patterns across the application
<!-- - Built-in testing support -->
<!-- - Well-documented conventions -->

### Modern Features
- Built-in Hotwire integration
- Responsive UI components
- Progressive enhancement
- Mobile-friendly by default

### Enterprise Ready
- Flexible and robust access control
<!-- - Audit logging -->
- Multi-tenancy support
<!-- - Scalable architecture -->

### Developer Flexibility
- Override any default behavior
- Custom resource actions
- Extensible component system
- Compatible with existing Rails patterns

## Developer Experience

### Familiar Territory

::: code-group
```ruby [Traditional Rails]
class ProductsController < ApplicationController
  def index
    @products = Product.all
  end

  # Rest of controller...
end
```

```ruby [Plutonium]
class ProductsController < ResourceController
end
```
:::

### Powerful Generators

```bash
# Generate a complete resource with CRUD operations
rails generate pu:res:scaffold Product name:string price:decimal

# Generate a package for modular organization
rails generate pu:pkg:package Inventory
```

### Clear Conventions

::: code-group
```ruby [Interaction]
class DiscontinueProduct < ResourceInteraction
  attribute :resource

  def execute
    if resource.discontinue
      succeed(resource).with_message("Product discontinued!")
    else
      failed(resource.errors)
    end
  end
end
```

```ruby [Definition]
class ProductDefinition < ResourceDefinition
  action :discontinue_product, interaction: DiscontinueProduct
end
```

```ruby [Policy]
class ProductPolicy < ResourcePolicy
  def discontinue_product?
    !record.discontinued?
  end
end
```

:::

### Customization Points

::: code-group
```ruby [Fields]
class ProductDefinition < ResourceDefinition
  # Define common options for a field
  field :description, as: :markdown

  # Define display specific options
  display :name, class: "col-span-full"

  # Define input specific options
  input :category, choices: ["Software", "Hardware"]

  # Define column specific options
  column :price, align: :right
end
```

```ruby [Sorting]
class ProductDefinition < ResourceDefinition
  # Sort by a single column
  sort :id

  # Sort by multiple columns
  sorts :category, :created_at

  # Sort using a custom strategy
  sort :name do |scope, direction:|
   scope.order(custom_field: direction)
  end
end
```


```ruby [Searching]
class ProductDefinition < ResourceDefinition
  search do |scope, query|
    scope.where("name LIKE ?", "%#{query}%")
  end
end
```

```ruby [Scoping]
class ProductDefinition < ResourceDefinition
  scope :software do |scope|
    scope.where("category = 'Software'")
  end

  scope :hardware do |scope|
    scope.where("category = 'Hardware'")
  end
end
```

```ruby [Filtering]
class ProductDefinition < ResourceDefinition
  # Define a filter on a column
  filter :name, with: TextFilter, predicate: :matches

  # Define a custom filter inline
  filter :created_after, with: proc { |scope, date:| scope.where("created_at > ?", date) } do |filter|
    filter.input :date
  end
end
```
:::

<!--

## Best Practices

::: tip Package Organization
- Group related resources in packages
- Keep packages focused and cohesive
- Use namespacing to avoid conflicts
:::

::: tip Resource Design
- Define clear policies for each resource
- Use interactions for business logic
- Keep presenters focused on display logic
:::

::: tip Testing
- Test policies thoroughly
- Write integration tests for interactions
- Use fixture factories wisely
:::

::: warning Performance
- Use query objects for complex queries
- Implement caching where appropriate
- Monitor N+1 queries
:::

::: danger Security
- Always define explicit policies
- Use authorization consistently
- Validate all inputs thoroughly
:::

## Additional Resources

| Resource | Description |
|----------|-------------|
| [API Documentation](https://docs.plutonium.dev/api) | Complete API reference |
| [Guides and Tutorials](https://docs.plutonium.dev/guides) | Step-by-step tutorials |
| [Example Applications](https://github.com/radioactive-labs/plutonium-examples) | Real-world examples |
| [Contributing Guide](https://github.com/radioactive-labs/plutonium-core/CONTRIBUTING.md) | How to contribute |

## Community and Support

Need help? Here are ways to get support:

- 💬 [Discord Community](https://discord.gg/plutonium)
- 📝 [GitHub Issues](https://github.com/radioactive-labs/plutonium-core/issues)
- 🤔 [Stack Overflow](https://stackoverflow.com/questions/tagged/plutonium-rails)

## License

Plutonium is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT). -->
