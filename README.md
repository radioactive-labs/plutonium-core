# Plutonium

[![Gem Version](https://badge.fury.io/rb/plutonium.svg)](https://badge.fury.io/rb/plutonium)
[![Ruby](https://github.com/radioactive-labs/plutonium-core/actions/workflows/main.yml/badge.svg)](https://github.com/radioactive-labs/plutonium-core/actions/workflows/main.yml)

Build production-ready Rails apps in hours, not weeks. Convention-driven, fully customizable, and AI-ready. Plutonium picks up where Rails left off, adding application-level concepts that make building complex apps faster.

## Quick Start

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

Then create your first resource:

```bash
cd myapp
rails g pu:res:scaffold Post title:string body:text --dest=main_app
rails db:migrate
bin/dev
```

Visit `http://localhost:3000` - you have a complete CRUD interface.

## What You Get

**Resource-oriented architecture** - Models, policies, definitions, and controllers that work together:

```ruby
# Policy controls WHO can do WHAT
class PostPolicy < ResourcePolicy
  def create? = user.present?
  def update? = record.author == user || user.admin?

  def permitted_attributes_for_create
    %i[title body]
  end
end

# Definition controls HOW it renders
class PostDefinition < ResourceDefinition
  input :body, as: :markdown
  search { |scope, q| scope.where("title ILIKE ?", "%#{q}%") }
  scope :published
  scope :drafts
end
```

**Packages for organization** - Split your app into feature packages and portals:

```bash
rails g pu:pkg:package blogging      # Business logic
rails g pu:pkg:portal admin          # Web interface
rails g pu:res:conn Post --dest=admin_portal
```

**Built-in authentication** via Rodauth:

```bash
rails g pu:rodauth:install
rails g pu:rodauth:account user
```

**Multi-tenancy** with entity scoping:

```ruby
# In portal engine
scope_to_entity Organization, strategy: :path
# Routes become /organizations/:organization_id/posts
```

**Custom actions** with interactions:

```ruby
class PublishInteraction < ResourceInteraction
  attribute :resource
  attribute :publish_at, :datetime

  def execute
    resource.update!(published_at: publish_at)
    succeed(resource).with_message("Published!")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

## Documentation

Full documentation at **[radioactive-labs.github.io/plutonium-core](https://radioactive-labs.github.io/plutonium-core/)**

- [Installation](https://radioactive-labs.github.io/plutonium-core/getting-started/installation)
- [Tutorial](https://radioactive-labs.github.io/plutonium-core/getting-started/tutorial/)
- [Guides](https://radioactive-labs.github.io/plutonium-core/guides/)
- [Reference](https://radioactive-labs.github.io/plutonium-core/reference/)

## Requirements

- Ruby 3.2+
- Rails 7.1+ (Rails 8 recommended)
- Node.js 18+

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## Status

Plutonium is used in production but still evolving. APIs may change between minor versions. Pin your version in Gemfile.

## License

MIT License - see [LICENSE](LICENSE).
