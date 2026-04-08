---
name: plutonium
description: Use when starting work on a Plutonium app, unsure which skill to read, or need an overview of the resource architecture
---

# Plutonium Development Guide

Read this first when working on a Plutonium application.

## Core Rules

1. **Always use generators** - Never manually create resources, packages, or portals
2. **Check relevant skills first** - Each concept has a dedicated skill with details
3. **Definitions over controllers** - UI customization belongs in definitions, not controllers
4. **Policies for authorization** - All permission logic goes in policies

## Key Generators

```bash
rails g pu:res:scaffold Post title:string --dest=main_app    # Create resource
rails g pu:res:conn Post --dest=admin_portal                 # Connect to portal
rails g pu:pkg:package blogging                              # Create feature package
rails g pu:pkg:portal admin                                  # Create portal
```

Always specify `--dest` to avoid interactive prompts.

## Unattended Execution

Plutonium generators are interactive by default. When running them from scripts, agents, or CI, pass these flags to prevent blocking prompts:

| Flag | Generators | Purpose |
|------|-----------|---------|
| `--dest=main_app` or `--dest=package_name` | `pu:res:scaffold`, `pu:res:conn`, and other resource/package-targeted generators | Skips the "Select destination feature" prompt |
| `--force` | any generator | Overwrites conflicting files without the `[Ynaqdhm]` prompt (needed when re-running `pu:saas:setup` or regenerating existing files) |
| `--auth=<account>` / `--public` / `--byo` | `pu:pkg:portal` | Skips the authentication-type prompt |
| `--skip-bundle` | generators that install gems | Avoids a mid-run `bundle install` |
| `--quiet` | most generators | Reduces output noise |

If a generator chains to others (e.g. `pu:saas:setup`), these flags propagate to the subgenerators — always pass `--force` when re-running a meta-generator on an app that already has some of its outputs.

## Resource Architecture

A **resource** is four layers working together for full CRUD with minimal code:

| Layer | File | Purpose | Customize when... |
|-------|------|---------|-------------------|
| **Model** | `app/models/post.rb` | Data, validations, associations | Adding business logic |
| **Definition** | `app/definitions/post_definition.rb` | UI - fields, actions, filters | Changing how things look/behave |
| **Policy** | `app/policies/post_policy.rb` | Authorization - who can do what | Restricting access |
| **Controller** | `app/controllers/posts_controller.rb` | Request handling | Rarely - use hooks if needed |

```
┌─────────────────────────────────────────────────────────────────┐
│                           Resource                              │
├─────────────────────────────────────────────────────────────────┤
│  Model          │  Definition      │  Policy        │ Controller│
│  (WHAT it is)   │  (HOW it looks)  │  (WHO can act) │ (HOW it   │
│                 │                  │                │  responds) │
├─────────────────────────────────────────────────────────────────┤
│  - attributes   │  - field types   │  - permissions │ - CRUD    │
│  - associations │  - inputs/forms  │  - scoping     │ - redirects│
│  - validations  │  - displays      │  - attributes  │ - params  │
│  - scopes       │  - actions       │                │           │
│  - callbacks    │  - filters       │                │           │
└─────────────────────────────────────────────────────────────────┘
```

## Auto-Detection

Plutonium automatically detects from your model:
- All database columns with appropriate field types
- Associations (belongs_to, has_one, has_many)
- Attachments (Active Storage)
- Enums

**You only need to declare when overriding defaults.**

## Creating Resources

### New Resources (from scratch)

```bash
rails g pu:res:scaffold Post user:belongs_to title:string 'content:text?' published:boolean --dest=main_app
```

See `plutonium-create-resource` skill for full generator options.

### From Existing Models

1. Include `Plutonium::Resource::Record` in your model (or inherit from a class that does)
2. Generate supporting files: `rails g pu:res:scaffold Post --no-migration`
3. Connect to a portal: `rails g pu:res:conn Post --dest=admin_portal`

## Connecting to Portals

Resources must be connected to a portal to be accessible:

```bash
rails g pu:res:conn Post --dest=admin_portal
```

See `plutonium-portal` skill for portal details.

## Portal-Specific Customization

Each portal can override the base definition, policy, and controller:

```ruby
# Admin portal sees more
class AdminPortal::PostDefinition < ::PostDefinition
  scope :draft
  scope :pending_review
  action :feature, interaction: FeaturePostInteraction
end
```

## Workflow Summary

1. **Generate** - `rails g pu:res:scaffold Model attributes... --dest=main_app`
2. **Migrate** - `rails db:migrate`
3. **Connect** - `rails g pu:res:conn Model --dest=portal_name`
4. **Customize** - Edit definition/policy as needed

## Skill Reference

| Topic | Skill |
|-------|-------|
| Creating resources | `plutonium-create-resource` |
| Models & features | `plutonium-model` |
| Field configuration | `plutonium-definition` |
| Actions & interactions | `plutonium-definition-actions` |
| Search, filters, scopes | `plutonium-definition-query` |
| Authorization | `plutonium-policy` |
| Custom views | `plutonium-views` |
| Custom forms | `plutonium-forms` |
| Nested resources | `plutonium-nested-resources` |
| Packages & portals | `plutonium-package`, `plutonium-portal` |
| Authentication | `plutonium-rodauth` |
| Interactions | `plutonium-interaction` |
| Theming & assets | `plutonium-theming`, `plutonium-assets` |
| User profile | `plutonium-profile` |
| User invites | `plutonium-invites` |
| Installation | `plutonium-installation` |
