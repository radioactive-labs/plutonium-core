---
name: plutonium
description: Use BEFORE starting any Plutonium work — new app, new feature, or first edit in an unfamiliar area. Routes you to the right skills and bootstraps greenfield work.
---

# Plutonium — Router & Bootstrapper

This skill is the entry point for all Plutonium work. It does three things:

1. Surfaces the **most expensive mistakes** up front (🚨 below).
2. Tells you which foundational skills to load for **greenfield** work.
3. Maps specific "about to…" actions to the right **targeted skill** (router table).

Read this first. Then follow the pointers.

## 🚨 Critical (read first)

- **Plutonium is generator-driven.** Almost every file you'd hand-write has a `pu:*` generator. Use it. Hand-written files drift from conventions and break future generator runs.
- **For greenfield** (new app, substantial new feature, first resource in a new domain) — load the **bootstrap bundle** below before writing code.
- **For targeted edits** — use the **router table** to jump straight to the right skill.
- **For anything touching tenant scoping** — load `plutonium-entity-scoping`. Don't reach for `where(organization: ...)` in a policy; fix the model instead.
- **Unattended execution:** always pass `--dest=`, `--force` (when re-running meta-generators), `--auth=`, `--skip-bundle`, and `--quiet` so generators don't block on prompts. See [Unattended execution](#unattended-execution).

## Greenfield bootstrap bundle

Triggers: installing Plutonium, building a new app, adding the first resource in a new domain, setting up a new portal or package, "build me a Y app", "set up X from scratch".

**Load ALL of these before writing code:**

1. **`plutonium-installation`** — `pu:core:install`, Rails template vs existing app, base classes.
2. **`plutonium-create-resource`** — `pu:res:scaffold` syntax, field types, destinations.
3. **`plutonium-model`** — model structure, associations, `has_cents`, labeling, routing.
4. **`plutonium-policy`** — authorization actions, `permitted_attributes_for_*`, derived methods.
5. **`plutonium-entity-scoping`** — `associated_with`, `default_relation_scope`, model shapes for multi-tenancy.
6. **`plutonium-portal`** — `pu:pkg:portal`, mounting, resource connection, entity strategies.
7. **`plutonium-definition`** — fields, inputs, displays, search, filters, scopes, actions.

Optional additions when relevant:
- **`plutonium-auth`** for login / accounts / profile.
- **`plutonium-invites`** for membership-based onboarding.
- **`plutonium-package`** when splitting logic across feature packages.
- **`plutonium-assets`** when customizing Tailwind / Stimulus / tokens.

## Router table

| About to… | Load |
|---|---|
| Write/edit a model, add associations, use `has_cents` | `plutonium-model` |
| Scope a model to a tenant, write `associated_with`, deal with multi-tenancy | **`plutonium-entity-scoping`** |
| Write `relation_scope`, `permitted_attributes`, override a policy | `plutonium-policy` (+ `plutonium-entity-scoping` if scoping) |
| Create a new resource via `pu:res:scaffold` | `plutonium-create-resource` |
| Add fields, inputs, displays, search, filters, scopes, custom actions, or bulk actions | `plutonium-definition` |
| Write an interaction class for business logic | `plutonium-interaction` |
| Customize a controller action, hook, redirect, or param | `plutonium-controller` |
| Build a custom page, panel, table, layout, Phlex component | `plutonium-views` |
| Customize forms, field builders, inputs, submit buttons | `plutonium-forms` |
| Configure Tailwind, register a Stimulus controller, edit design tokens | `plutonium-assets` |
| Set up Rodauth, accounts, login flows, or profile / settings page | `plutonium-auth` |
| Set up user invitations or entity membership | `plutonium-invites` (+ `plutonium-entity-scoping`) |
| Configure parent/child resources, nested routes | `plutonium-nested-resources` |
| Create a portal or feature package | `plutonium-portal` / `plutonium-package` |
| Mount a portal, configure entity strategies, route portal resources | `plutonium-portal` (+ `plutonium-entity-scoping` for tenancy) |
| Install Plutonium in a Rails app | `plutonium-installation` |
| Write tests for a resource, run `pu:test:scaffold`, or include `Plutonium::Testing::*` concerns | `plutonium-testing` |

## Generator catalog

Every Plutonium generator is discoverable via `rails g pu:<tab>`. Always pass `--dest=` to skip prompts.

| Generator | Purpose | Covered by |
|---|---|---|
| `pu:core:install` | Initial Plutonium setup (base controller/policy/definition/layout) | `plutonium-installation` |
| `pu:core:assets` | Install custom Tailwind + Stimulus toolchain | `plutonium-assets` |
| `pu:res:scaffold NAME field:type ...` | Create a new resource (model, migration, controller, policy, definition) | `plutonium-create-resource` |
| `pu:res:conn RESOURCE --dest=PORTAL` | Connect a resource to a portal | `plutonium-portal` |
| `pu:pkg:package NAME` | Create a feature package | `plutonium-package` |
| `pu:pkg:portal NAME --auth=... --scope=...` | Create a portal package | `plutonium-portal` |
| `pu:rodauth:install` | Install Rodauth base | `plutonium-auth` |
| `pu:rodauth:account NAME` | Create a basic Rodauth account | `plutonium-auth` |
| `pu:rodauth:admin NAME` | Create a hardened admin account (2FA, lockout, audit) | `plutonium-auth` |
| `pu:saas:setup --user ... --entity ...` | Meta-generator: user + entity + membership + portal + profile + welcome + invites | `plutonium-auth` + `plutonium-invites` |
| `pu:saas:user / :entity / :membership` | Individual SaaS pieces | `plutonium-auth` |
| `pu:saas:portal / :welcome` | SaaS portal & onboarding | `plutonium-auth` + `plutonium-portal` |
| `pu:profile:install / :setup / :conn` | User profile resource + security section | `plutonium-auth` |
| `pu:invites:install` | User invitations package | `plutonium-invites` |
| `pu:invites:invitable NAME` | Mark a model as invitable | `plutonium-invites` |
| `pu:field:input NAME` | Custom form input component | `plutonium-forms` |
| `pu:field:renderer NAME` | Custom display renderer | `plutonium-definition` |
| `pu:eject:layout` | Eject the base layout for customization | `plutonium-views` |
| `pu:skills:sync` | Sync Plutonium Claude skills into the project | `plutonium` |
| `pu:test:install` | Install Plutonium::Testing scaffolding | `plutonium-testing` |
| `pu:test:scaffold NAME --portals=...` | Scaffold integration tests per (resource × portal) | `plutonium-testing` |

## Resource architecture at a glance

A **resource** is four cooperating layers:

| Layer | File | Purpose | Edit when… |
|---|---|---|---|
| **Model** | `app/models/post.rb` | Data, validations, associations | Adding domain data/logic |
| **Definition** | `app/definitions/post_definition.rb` | UI — fields, filters, actions | Changing how it looks/behaves |
| **Policy** | `app/policies/post_policy.rb` | Authorization — who, what | Restricting access |
| **Controller** | `app/controllers/posts_controller.rb` | Request handling | Rarely — use hooks |

```
┌───────────────────────────────────────────────────────────────┐
│                          Resource                             │
├───────────────────────────────────────────────────────────────┤
│  Model          │  Definition     │  Policy       │ Controller │
│  (WHAT)         │  (HOW it looks) │  (WHO)        │  (HOW it   │
│                 │                 │               │   responds)│
├───────────────────────────────────────────────────────────────┤
│  - attributes   │  - field types  │  - actions    │ - CRUD     │
│  - associations │  - inputs/forms │  - attributes │ - hooks    │
│  - validations  │  - displays     │  - scoping    │ - redirects│
│  - scopes       │  - filters      │               │ - params   │
└───────────────────────────────────────────────────────────────┘
```

Auto-detection fills most of these in from your model — you only declare when **overriding defaults**.

## Unattended execution

Plutonium generators are interactive by default. For scripts, agents, or CI, pass these flags:

| Flag | Generators | Purpose |
|---|---|---|
| `--dest=main_app` / `--dest=package_name` | `pu:res:scaffold`, `pu:res:conn`, package-targeted generators | Skips "Select destination feature" prompt |
| `--force` | any | Overwrites conflicting files (needed when re-running `pu:saas:setup` or meta-generators) |
| `--auth=<account>` / `--public` / `--byo` | `pu:pkg:portal` | Skips auth-type prompt |
| `--skip-bundle` | gem-installing generators | Avoids mid-run `bundle install` |
| `--quiet` | most | Reduces output noise |

Meta-generators (`pu:saas:setup`) propagate these flags to the generators they chain. Always pass `--force` when re-running a meta-generator on an app that already has some of its outputs.

## Workflow summary

1. **Load the bootstrap bundle** (or the targeted skill from the router table).
2. **Generate** — `rails g pu:res:scaffold Model field:type ... --dest=main_app`.
3. **Migrate** — `rails db:migrate`.
4. **Connect** — `rails g pu:res:conn Model --dest=portal_name`.
5. **Customize** — edit definition / policy as needed.
6. **Verify** — hit the route in the browser.

## See also

- `plutonium-installation` · `plutonium-create-resource` · `plutonium-model` · `plutonium-policy` · `plutonium-entity-scoping` · `plutonium-portal` · `plutonium-definition`
- `plutonium-controller` · `plutonium-interaction` · `plutonium-views` · `plutonium-forms` · `plutonium-assets`
- `plutonium-auth` · `plutonium-invites` · `plutonium-package` · `plutonium-nested-resources`
- `plutonium-testing` — default test concerns and scaffolding
