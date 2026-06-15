---
name: plutonium
description: Use BEFORE starting any Plutonium work — new app, new feature, or first edit in an unfamiliar area. Routes you to the right skill and bootstraps greenfield work.
---

# Plutonium — Router & Bootstrapper

Entry point for all Plutonium work. Does three things:

1. Surfaces the **most expensive mistakes** up front (🚨 below).
2. Tells you which skills to load for **greenfield** work.
3. Maps specific "about to…" actions to the right targeted skill (router table).

## 🚨 Critical (read first)

- **Plutonium is generator-driven.** Almost every file you'd hand-write has a `pu:*` generator. Hand-written files drift from conventions and break future generator runs.
- **For greenfield** (new app, substantial new feature, first resource in a new domain) — load the **bootstrap bundle** below before writing code.
- **For targeted edits** — use the **router table** to jump to the right skill.
- **For anything touching tenant scoping** — load `plutonium-tenancy`. Don't reach for `where(organization: ...)` in a policy; fix the model instead.
- **Unattended execution:** always pass `--dest=`, `--force` (when re-running meta-generators), `--auth=`, `--skip-bundle`, `--quiet` so generators don't block on prompts. See [Unattended execution](#unattended-execution).

## The skills

| Skill | Covers |
|---|---|
| **[[plutonium-app]]** | Installation, packages (feature + portal), portal engines, mounting, `register_resource` (including singular and custom routes), `pu:res:conn` |
| **[[plutonium-resource]]** | The resource itself — `pu:res:scaffold`, field types, model layer (`Plutonium::Resource::Record`, `has_cents`, SGID, routing), definition layer (fields/inputs/displays/columns, search/filters/scopes/sorting, custom actions, bulk actions, index views, page customization) |
| **[[plutonium-behavior]]** | Controllers (hooks, key methods, presentation), policies (action methods, `permitted_attributes_for_*`, `permitted_associations`), interactions (structure, outcomes, chaining, URL generation) |
| **[[plutonium-ui]]** | Page classes, forms, displays, tables, custom Phlex components, layouts, modals & tabs, Tailwind config, Stimulus, design tokens, `.pu-*` classes, Phlexi themes |
| **[[plutonium-auth]]** | Rodauth install, account types (basic / admin / SaaS), profile resource, security section |
| **[[plutonium-tenancy]]** | Entity scoping (`associated_with`, `default_relation_scope`, three model shapes), nested resources, invites |
| **[[plutonium-testing]]** | `pu:test:install`, `pu:test:scaffold`, `ResourceCrud`/`ResourcePolicy`/`ResourceDefinition`/`ResourceModel`/`NestedResource`/`PortalAccess`/`ResourceInteraction`, `AuthHelpers` |
| **[[plutonium-wizard]]** | Multi-step flows — the wizard DSL (`step`/`review`/`using:`/`condition:`, per-step `on_submit`/`persist`/`on_rollback`, `execute`), anchoring & resume, one-time wizards + gate, registration (`wizard` macro + `register_wizard`), storage/config + SweepJob |

## Greenfield bootstrap bundle

Triggers: installing Plutonium, building a new app, adding the first resource in a new domain, setting up a new portal or package, "build me a Y app", "set up X from scratch".

**Load these before writing code:**

1. **`plutonium-app`** — install, portals, packages, routes.
2. **`plutonium-resource`** — scaffold, model, definition (the bulk of the work).
3. **`plutonium-behavior`** — controllers, policies, interactions.
4. **`plutonium-tenancy`** — only if multi-tenant; load before declaring entity scoping.

Add when relevant:
- **`plutonium-auth`** for login / accounts / profile.
- **`plutonium-ui`** for custom pages, forms, components, or theming.
- **`plutonium-testing`** when scaffolding tests.

## Router table

| About to… | Load |
|---|---|
| Install Plutonium, create a portal or package, mount engines, register routes (incl. singular / custom routes) | **[[plutonium-app]]** |
| Run `pu:res:scaffold`, pick field types, set scaffold options | **[[plutonium-resource]]** |
| Edit a model, add associations, use `has_cents`, override `to_param` / `to_label` | **[[plutonium-resource]]** |
| Edit a definition — fields, inputs, displays, columns, search, filters, scopes, custom actions, bulk actions, index views, modal/slideover, page titles | **[[plutonium-resource]]** |
| Override a controller action, hook, redirect, or `resource_params` | **[[plutonium-behavior]]** |
| Write `relation_scope`, `permitted_attributes_for_*`, `permitted_associations`, action methods, or any policy override | **[[plutonium-behavior]]** (+ **[[plutonium-tenancy]]** if scoping) |
| Write an interaction class for business logic | **[[plutonium-behavior]]** |
| Scope a model to a tenant, write `associated_with`, set portal entity strategy | **[[plutonium-tenancy]]** |
| Configure parent/child nested routes, custom parent resolution | **[[plutonium-tenancy]]** |
| Set up user invitations or entity membership | **[[plutonium-tenancy]]** |
| Build a custom page (override `ShowPage`/`IndexPage`/`NewPage`/`EditPage`), custom form, custom display, custom table, custom Phlex component | **[[plutonium-ui]]** |
| Configure Tailwind, register Stimulus controllers, edit design tokens, theme forms/displays/tables, write a custom layout | **[[plutonium-ui]]** |
| Install Rodauth, set up accounts, configure login flow, add the profile resource | **[[plutonium-auth]]** |
| Write tests for a resource, run `pu:test:scaffold`, include `Plutonium::Testing::*` concerns | **[[plutonium-testing]]** |
| Build a multi-step flow — onboarding, checkout, branching create — register a `wizard` / `register_wizard`, gate a one-time wizard | **[[plutonium-wizard]]** |

## Resource architecture at a glance

A **resource** is four cooperating layers — Plutonium auto-fills defaults from the model, so you only declare overrides:

| Layer | File | Purpose |
|---|---|---|
| **Model** | `app/models/post.rb` | Data, validations, associations |
| **Definition** | `app/definitions/post_definition.rb` | UI — fields, filters, actions |
| **Policy** | `app/policies/post_policy.rb` | Authorization — who, what |
| **Controller** | `app/controllers/posts_controller.rb` | Request handling (rarely edited — use hooks) |

Plus one optional fifth layer:

| Layer | File | Purpose |
|---|---|---|
| **Interaction** | `app/interactions/publish_post_interaction.rb` | Business logic for custom actions |

## Generator catalog

Every Plutonium generator is discoverable via `rails g pu:<tab>`. Always pass `--dest=` to skip prompts.

| Generator | Purpose | Skill |
|---|---|---|
| `pu:core:install` | Initial Plutonium setup | `plutonium-app` |
| `pu:core:assets` | Custom Tailwind + Stimulus toolchain | `plutonium-ui` |
| `pu:res:scaffold NAME field:type ...` | New resource (model, migration, controller, policy, definition) | `plutonium-resource` |
| `pu:res:conn RESOURCE --dest=PORTAL` | Connect resource to a portal | `plutonium-app` |
| `pu:pkg:package NAME` | Feature package | `plutonium-app` |
| `pu:pkg:portal NAME --auth=... --scope=...` | Portal package | `plutonium-app` |
| `pu:rodauth:install` | Install Rodauth base | `plutonium-auth` |
| `pu:rodauth:account NAME` | Basic Rodauth account | `plutonium-auth` |
| `pu:rodauth:admin NAME` | Hardened admin account (2FA, lockout, audit) | `plutonium-auth` |
| `pu:saas:setup --user ... --entity ...` | Meta: user + entity + membership + portal + profile + welcome + invites | `plutonium-auth` + `plutonium-tenancy` |
| `pu:saas:user / :entity / :membership / :portal / :welcome` | Individual SaaS pieces | `plutonium-auth` + `plutonium-app` |
| `pu:profile:install / :setup / :conn` | Profile resource + security section | `plutonium-auth` |
| `pu:invites:install` | User invitations package | `plutonium-tenancy` |
| `pu:invites:invitable NAME` | Mark a model as invitable | `plutonium-tenancy` |
| `pu:eject:layout` | Eject base layout for customization | `plutonium-ui` |
| `pu:eject:shell` | Eject topbar/sidebar partials | `plutonium-ui` |
| `pu:test:install` | Install `Plutonium::Testing` scaffolding | `plutonium-testing` |
| `pu:test:scaffold NAME --portals=...` | Scaffold integration tests | `plutonium-testing` |
| `pu:skills:sync` | Sync Plutonium Claude skills into the project | (this skill) |

## Unattended execution

Plutonium generators are interactive by default. For scripts, agents, or CI:

| Flag | Generators | Purpose |
|---|---|---|
| `--dest=main_app` / `--dest=<package>` | `pu:res:scaffold`, `pu:res:conn`, package-targeted generators | Skip "select destination" prompt |
| `--force` | any | Overwrite conflicting files (required when re-running `pu:saas:setup` or meta-generators) |
| `--auth=<account>` / `--public` / `--byo` | `pu:pkg:portal` | Skip auth-type prompt |
| `--skip-bundle` | gem-installing generators | Avoid mid-run `bundle install` |
| `--quiet` | most | Reduce output noise |

Meta-generators (`pu:saas:setup`) propagate flags to the generators they chain. Always pass `--force` when re-running a meta-generator on an app that already has some of its outputs.

## Workflow summary

1. **Load the bootstrap bundle** (or the targeted skill from the router table).
2. **Generate** — `rails g pu:res:scaffold Model field:type ... --dest=main_app`.
3. **Migrate** — `rails db:prepare`.
4. **Connect** — `rails g pu:res:conn Model --dest=portal_name`.
5. **Customize** — edit definition / policy as needed.
6. **Verify** — hit the route in the browser.
