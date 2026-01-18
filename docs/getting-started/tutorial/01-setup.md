# Chapter 1: Project Setup

In this chapter, you'll create a new Plutonium application and explore its structure.

## Creating the Application

Open your terminal and run:

```bash
rails new blog -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

This creates a new Rails application with Plutonium pre-configured.

When prompted, accept the defaults or customize as needed. The template will:
- Install the Plutonium gem
- Configure TailwindCSS 4
- Set up Rodauth for authentication
- Create the database schema

## Starting the Server

```bash
cd blog
bin/dev
```

Visit `http://localhost:3000`. You should see a welcome page.

## Project Structure

Let's explore what was created:

```
blog/
├── app/
│   ├── controllers/         # Standard Rails controllers
│   ├── definitions/         # Plutonium definitions (how resources render)
│   ├── interactions/        # Business logic classes
│   ├── models/              # Standard Rails models
│   ├── policies/            # Authorization policies
│   └── views/               # Phlex view components
├── packages/                # Feature packages and portals
│   └── .keep
├── config/
│   └── initializers/
│       └── plutonium.rb     # Plutonium configuration
└── ...
```

### Key Directories

**`app/definitions/`** - Contains Definition classes that control how resources are displayed. Fields, forms, tables, and actions are configured here.

**`app/policies/`** - Contains Policy classes that control authorization. Who can do what with each resource.

**`app/interactions/`** - Contains Interaction classes for complex business logic. Used for custom actions beyond simple CRUD.

**`packages/`** - Contains Feature Packages (business logic modules) and Portal Packages (web interfaces).

## Understanding Packages

Plutonium uses two types of packages:

### Feature Packages

Feature packages contain your business logic - models, definitions, policies, interactions, and controllers. They're Rails engines that can be shared across multiple portals.

```
packages/
└── blogging/                # Feature package
    ├── app/
    │   ├── controllers/blogging/
    │   ├── definitions/blogging/
    │   ├── interactions/blogging/
    │   ├── models/blogging/
    │   ├── policies/blogging/
    │   └── views/blogging/
    └── lib/
        └── engine.rb
```

### Portal Packages

Portal packages are web interfaces that expose resources to users. Each portal can have its own authentication, authorization rules, and UI customizations.

```
packages/
└── admin_portal/            # Portal package
    ├── app/
    │   ├── controllers/admin_portal/
    │   └── views/admin_portal/
    └── lib/admin_portal/
        └── engine.rb
```

## Configuration

Open `config/initializers/plutonium.rb`:

```ruby
Plutonium.configure do |config|
  config.load_defaults 1.0

  # Configure plutonium above.
end
```

The defaults work well out of the box. Available options include:
- `config.development` - Enable development mode
- `config.cache_discovery` - Cache resource discovery (auto-configured per environment)
- `config.assets.logo` - Custom logo path

## What's Next

In the next chapter, we'll create our first resource - the Post model with its definition and policy.

[Continue to Chapter 2: Creating Your First Resource →](./02-first-resource)
