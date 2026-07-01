---
title: Plutonium for AI Agents
description: Machine-readable entry point for AI coding agents building Rails apps with Plutonium — install commands, conventions, generator catalog, and skill files.
sidebar: false
---

# Plutonium for AI Agents

You are reading the agent entry point for **Plutonium**, a Rails RAD framework (Ruby gem) that provides resource-oriented architecture: automatic CRUD, authorization policies, declarative UI definitions, authentication, and multi-tenancy. If a user asked you to build something with Plutonium, this page gives you the golden path and where to read next.

## Machine-readable resources

| Resource | URL |
|---|---|
| Docs index (llms.txt) | `https://radioactive-labs.github.io/plutonium-core/llms.txt` |
| Full docs, one file | `https://radioactive-labs.github.io/plutonium-core/llms-full.txt` |
| Agent skills index | `https://radioactive-labs.github.io/plutonium-core/skills/index.md` |
| Router skill (start here) | `https://radioactive-labs.github.io/plutonium-core/skills/plutonium.md` |

Every docs page also has a raw markdown twin: append `.md` to its URL (e.g. `/guides/multi-tenancy.md`).

**Prefer the skills over the raw docs.** They are task-focused, deduplicated, and encode the mistakes agents actually make. The router skill maps "about to do X" to the right skill file. If you are Claude Code, run `rails g pu:skills:sync` after installing the gem to install them into `.claude/skills/` so they load automatically.

## Rules that prevent expensive mistakes

1. **Plutonium is generator-driven.** Nearly every file has a `pu:*` generator. Generate, then edit — never hand-write models, definitions, policies, or packages from scratch. Hand-written files drift from conventions and break future generator runs.
2. **Inspect before you act.** Check `Gemfile` for `plutonium`, `ls config/packages.rb`, and `ls packages/` before installing or scaffolding anything.
3. **New app → `plutonium.rb` template. Existing app → `base.rb` template.** Never run `plutonium.rb` on an existing app; it re-runs full bootstrap and clobbers git history.
4. **Pass flags to avoid interactive prompts**: `--dest=main_app` (or `--dest=<package>`), `--force` when re-running meta-generators, `--auth=<account>` for portals, `--skip-bundle`, `--quiet`.
5. **Quote field arguments with special characters**: `'title:string?'`, `'price:decimal{10,2}'`.
6. **Multi-tenancy is structural, not filtered in policies.** The portal declares `scope_to_entity`; the model provides the association path that `associated_with` resolves. Never `where(organization: ...)` in a policy — read the tenancy skill first.

## Golden path: new application

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
cd myapp
rails db:prepare
```

Then for each resource:

```bash
rails g pu:res:scaffold Post 'title:string' 'body:text?' user:references --dest=main_app
rails db:prepare
rails g pu:res:conn Post --dest=<portal_package>
```

## Golden path: existing application

```bash
bin/rails app:template \
  LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/base.rb
```

Or manually: add `gem "plutonium"` to the Gemfile, `bundle install`, then `rails g pu:core:install`.

## Architecture in one table

A **resource** is four cooperating layers. Plutonium auto-fills defaults from the model; you only declare overrides.

| Layer | File | Purpose |
|---|---|---|
| Model | `app/models/post.rb` | Data, validations, associations |
| Definition | `app/definitions/post_definition.rb` | UI — fields, filters, actions |
| Policy | `app/policies/post_policy.rb` | Authorization |
| Controller | `app/controllers/posts_controller.rb` | Rarely edited — use hooks |
| Interaction (optional) | `app/interactions/publish_post_interaction.rb` | Business logic for custom actions |

Resources live in the main app or in **feature packages**; users access them through **portal packages** (Rails engines with their own auth and optional tenant scoping).

## Generator catalog

Discover all generators with `rails g --help | grep pu:`. The most used:

| Generator | Purpose |
|---|---|
| `pu:core:install` | Initial Plutonium setup |
| `pu:res:scaffold NAME field:type ... --dest=` | New resource (model, migration, policy, definition) |
| `pu:res:conn RESOURCE --dest=PORTAL` | Connect a resource to a portal |
| `pu:pkg:package NAME` | Feature package |
| `pu:pkg:portal NAME --auth=...` | Portal package |
| `pu:rodauth:install` / `pu:rodauth:account NAME` | Authentication |
| `pu:saas:setup --user ... --entity ...` | Full SaaS bootstrap: user + tenant + membership + portal |
| `pu:test:install` / `pu:test:scaffold NAME` | Testing scaffolds |
| `pu:skills:sync` | Install the agent skill files into the project |

## Verify your work

```bash
rails runner "puts Plutonium::VERSION"   # gem installed and loaded
rails db:prepare                          # migrations applied
bin/dev                                   # boot; visit the portal route
```

## For humans reading this

This page exists so AI coding agents can bootstrap correctly on the first try. Point your agent at it, or just say: *"Read https://radioactive-labs.github.io/plutonium-core/ai.md before starting."* The [Getting Started guide](/getting-started/) covers the same ground for people.
