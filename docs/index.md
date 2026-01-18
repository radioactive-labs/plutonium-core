---
layout: home
hero:
  name: Plutonium
  text: Rapid Application Development for Rails
  tagline: Build production-ready Rails applications in minutes, not months. Convention-driven, fully customizable.
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started/
    - theme: alt
      text: View on GitHub
      link: https://github.com/radioactive-labs/plutonium-core

features:
  - icon: 🚀
    title: Zero to Production Fast
    details: Generate complete CRUD interfaces with a single command. Authentication, authorization, and UI included out of the box.
  - icon: 🧩
    title: Modular Architecture
    details: Organize your app into Feature Packages and Portals. Each module is isolated, testable, and reusable.
  - icon: 🎨
    title: Fully Customizable
    details: Every layer is overridable. Customize fields, forms, tables, pages, and styles without fighting the framework.
  - icon: 🔐
    title: Built-in Authorization
    details: Policy-based authorization at every level - actions, attributes, and collection scoping. Multi-tenancy ready.
  - icon: 📦
    title: Convention over Configuration
    details: Smart defaults detect your models, associations, and validations. Only configure what you need to change.
  - icon: 🛠️
    title: Rails Native
    details: Built on Rails conventions. Uses Phlex for views, Rodauth for auth, and standard Rails patterns throughout.
---

## Why Plutonium?

Building admin panels, dashboards, and internal tools in Rails often means:
- Writing repetitive CRUD code
- Building authorization from scratch
- Creating forms and tables manually
- Handling multi-tenancy yourself

**Plutonium eliminates this boilerplate** while remaining fully customizable.

```bash
# Create a new Plutonium app
rails new myapp -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb

# Generate a resource
rails g pu:res:scaffold Post title:string body:text published:boolean

# Connect it to a portal
rails g pu:res:conn Post --dest=admin_portal

# Done. Full CRUD with auth, policies, and UI.
```

## How It Works

Plutonium follows a layered architecture where each layer has a single responsibility:

| Layer | Purpose | File |
|-------|---------|------|
| **Model** | Data structure and validations | `app/models/post.rb` |
| **Definition** | How the resource renders (fields, actions) | `app/definitions/post_definition.rb` |
| **Policy** | Who can do what | `app/policies/post_policy.rb` |
| **Controller** | HTTP handling and customization | `app/controllers/posts_controller.rb` |

Each layer auto-detects sensible defaults. You only write code when you need to customize.

## Quick Links

<div class="quick-links">

- [Installation Guide](/getting-started/installation) - Set up Plutonium in a new or existing Rails app
- [Tutorial](/getting-started/tutorial/) - Build a complete blog application step by step
- [Architecture Overview](/concepts/architecture) - Understand how the pieces fit together
- [Reference Documentation](/reference/model/) - Detailed API documentation

</div>
