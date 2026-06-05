# Plutonium

[![Gem Version](https://badge.fury.io/rb/plutonium.svg)](https://badge.fury.io/rb/plutonium)
[![Ruby](https://github.com/radioactive-labs/plutonium-core/actions/workflows/main.yml/badge.svg)](https://github.com/radioactive-labs/plutonium-core/actions/workflows/main.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.txt)

**The Rails framework for things you should never write again.**

Convention over configuration, extended to everything you keep rebuilding: **CRUD. Auth. Authorization. Multi-tenancy. Admin portals. Search, filters, bulk actions.** All generated. All customizable. All Rails.

## Quick Start

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

Then scaffold a resource, create a portal, and connect them:

```bash
cd myapp

# Scaffold a resource — model, migration, definition, policy
rails g pu:res:scaffold Post title:string body:text published_at:datetime --dest=main_app
rails db:prepare

# Create a portal (web interface) and connect the resource to it
rails g pu:pkg:portal app --public
rails g pu:res:conn Post --dest=app_portal

bin/dev
```

Visit `http://localhost:3000/app/posts` — you have a complete CRUD interface.

## What You Stop Writing

Same scaffold command you already know. A very different surface area.

```bash
rails g scaffold Post ...              # Rails:     just CRUD
rails g pu:res:scaffold Post ...       # Plutonium: full CRUD + search + filters + bulk actions
```

And it doesn't stop at scaffolds:

**Resource-oriented architecture** — models, policies, definitions, and controllers that work together:

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

**Packages and portals** — split your app into feature engines and themed web interfaces:

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
# In a portal engine
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

## Why Plutonium

- **Convention over configuration** — extended to resources, policies, portals, and tenancy, not just routes and views.
- **It's just Rails** — generated code lives in your repo. Edit it, override it, delete it. The "magic" is regular Ruby mixins you can read.
- **Multi-tenant ready** — path or domain tenancy, scoped relations, invites and memberships out of the box.
- **AI-readable** — predictable file layout and naming, plus built-in [Claude Code skills](.claude/skills) that teach AI assistants the patterns.

## Documentation

Full documentation at **[radioactive-labs.github.io/plutonium-core](https://radioactive-labs.github.io/plutonium-core/)**

- [Installation](https://radioactive-labs.github.io/plutonium-core/getting-started/installation)
- [Tutorial](https://radioactive-labs.github.io/plutonium-core/getting-started/tutorial/)
- [Guides](https://radioactive-labs.github.io/plutonium-core/guides/)
- [Reference](https://radioactive-labs.github.io/plutonium-core/reference/)

## Requirements

- Ruby 3.2.2+
- Rails 7.2+ (Rails 8 recommended)
- Node.js 18+

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License — see [LICENSE.txt](LICENSE.txt).
