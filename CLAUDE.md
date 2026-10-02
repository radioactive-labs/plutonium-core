# Plutonium Core Development Guide

This guide helps AI assistants contribute to the Plutonium framework itself.

> Personal, cross-project rules live in `~/.claude/CLAUDE.md` (never stage/commit
> unless asked, `rails runner` over console, `Rails.logger.warn { ... }` block
> syntax, `with_connection` over `connection`, inline migration indexes, Stimulus
> for interactivity and always register controllers, no defensive `respond_to?`
> checks, no Claude attribution in commits/PRs). Those are not repeated here.
> This file carries only what is specific to this repo.

## Project Overview

Plutonium is a Rails RAD framework distributed as a Ruby gem. It provides
resource-oriented architecture with automatic CRUD, policies, definitions, and
multi-tenancy. Assets (JS/CSS) ship inside the gem and are also published to npm.

## Repository Structure

```
plutonium-core/
├── lib/
│   ├── plutonium/              # Core framework code
│   │   ├── resource/           # Record, Policy, Definition, Controller, Interaction
│   │   ├── portal/             # Portal engines and multi-tenancy
│   │   ├── package/            # Feature-package engine mixin
│   │   ├── interaction/        # Business logic encapsulation
│   │   ├── dashboard/          # Dashboard DSL (metric / chart / card)
│   │   ├── kanban/             # Kanban board support
│   │   ├── wizard/             # Multi-step wizard DSL
│   │   ├── invites/            # Invitation model + token lifecycle
│   │   ├── rodauth/            # Rodauth integration
│   │   ├── positioning/        # Drag-to-reorder
│   │   ├── ui/                 # Phlex view components
│   │   ├── definition/         # Definition DSL and field types
│   │   ├── query/              # Search, filters, scopes
│   │   ├── routing/            # Route helpers and extensions
│   │   └── testing/            # Test helpers shipped to consumers
│   └── generators/pu/          # Rails generators (pu:*), NOT under lib/plutonium/
├── app/                        # Rails app components (assets, controllers, Phlex views)
├── src/                        # JS/CSS sources (built into app/assets and src/build)
├── test/
│   ├── plutonium/              # Unit tests mirroring lib/
│   ├── integration/            # Request/integration tests
│   ├── generators/             # Generator tests
│   ├── system/                 # System/browser tests
│   ├── support/                # Test helpers (generator_test_helper.rb, etc.)
│   └── dummy/                  # Test Rails app (see below)
├── docs/                       # VitePress docs; docs/public/skills/ is generated
├── .claude/skills/             # AI assistant skills (source of the shipped skills)
└── lib/tasks/release.rake      # Release automation
```

Generators live at `lib/generators/pu/<category>/`. Categories on disk:
`async_interactions, core, dashboard, docker, eject, extra, field, gem, gen,
invites, lib, lite, pkg, profile, res, rodauth, saas, service, skills, test,
wizards`. There is **no** `pu:res:interaction` generator: interactions are
hand-authored.

## Key Abstractions

### Resource System
- `Plutonium::Resource::Record`: model mixin with `associated_with` scopes
- `Plutonium::Resource::Policy`: ActionPolicy-based authorization
- `Plutonium::Resource::Definition`: declarative UI configuration
- `Plutonium::Resource::Controller`: CRUD controller mixin
- `Plutonium::Resource::Interaction`: business logic encapsulation

### Portal / Package System
- `Plutonium::Portal::Engine`: Rails engine mixin for web interfaces
- `Plutonium::Package::Engine`: Rails engine mixin for feature packages
- Entity scoping for multi-tenancy (path or custom strategy)

### UI Components
Phlex-based, under `lib/plutonium/ui/`: `page/`, `form/`, `table/`, `display/`,
`dashboard/`.

## The Dummy Test App (`test/dummy`)

This is where you exercise the framework end to end. Its packages are:
`admin_portal, blogging, catalog, locus_portal, org_portal, storefront_portal`.
Packages are auto-loaded by `config/packages.rb` globbing `packages/**/lib/engine.rb`.

### Always use generators here

Use the `pu:*` generators (`pu:res:scaffold`, `pu:res:conn`, `pu:pkg:portal`,
`pu:pkg:package`, etc.) to create dummy-app files, then customize the output.
**Why:** generators produce the correct file structure, inheritance, and marker
comments. Manual creation drifts into wrong patterns (making `ResourcePolicy` a
class instead of a module, missing the portal-module `include`, wrong inheritance
chain), and running the generator also validates that it works. Use `--policy`
and `--definition` on `pu:res:conn` when portal-specific overrides are needed.

### Databases

Every environment is SQLite (`test/dummy/config/database.yml`):
- `development` → `storage/development.sqlite3`
- `test` → `storage/test.sqlite3`
- `production` → multi-database: `primary`, `cache`, `queue`, `cable`

The **test** database is dropped, recreated, and migrated on every test boot
(`test/test_helper.rb`), so it has the current schema but zero rows.

### Running rails commands against the dummy

The dummy's own `Gemfile` is not installed; run everything through an appraisal
gemfile, from `test/dummy`:

```bash
cd test/dummy && env -u BUNDLE_GEMFILE \
  BUNDLE_GEMFILE="$(cd ../.. && pwd)/gemfiles/rails_8.1.gemfile" \
  bundle exec rails runner '<code>'
```

To seed data a running server will see, use a plain runner (do **not**
`require "test_helper"`, which drops the DB). Create a `User`
(`status = 2`, `password_hash = BCrypt::Password.create("password123")`), an
`Organization`, an `OrganizationUser` membership, then your records.

### Logins (seeds in `db/seeds.rb`)

Both logins are email-first (submit email, the same page reveals the password):
- User portal: `/users/login`, e.g. `alice@acme.com` / `password123`
- Admin portal: `/admins/login`, `admin@plutonium.dev` / `password123`. After
  admin login, `/` redirects to `/users/login` (home wants a user session), so
  navigate straight to `/admin/<resource>`.

Confirm which env/DB a running server is bound to before trusting it:
`lsof -p <pid> | grep sqlite3`, or watch which `*.sqlite3` mtime changes after an
action. A test-env server on an emptied `test.sqlite3` shows "no matching login"
because the users table is empty, not because credentials are wrong. Seeding the
wrong DB fails silently.

## Development Workflow

### Environment: `PLUTONIUM_DEV=1`

Set `PLUTONIUM_DEV=1` when working on the framework. It serves local assets,
hot-reloads components, and shows detailed errors.

Asset-source gotcha: `PLUTONIUM_DEV=1` reads `src/build/*.manifest`, which is the
output of `yarn dev`. If you only ran `yarn build` (which writes `app/assets/`),
a `PLUTONIUM_DEV=1` server 500s with a missing `src/build/css.manifest`. To serve
the packaged `app/assets/`, boot **without** `PLUTONIUM_DEV`. A stale
`src/build/css.manifest` can point at an old bundle, so when verifying anything
visual, grep the served CSS for the rule you expect rather than trusting the
manifest's presence.

Hot reload covers `lib/plutonium/**` and `packages/**` in **development** only
(the Listen-based `Plutonium::Reloader`). The **test**-env server does not reload,
so `lib/` edits there need a restart.

### Building assets

There is no `Procfile.dev`. Frontend work runs through yarn:

```bash
yarn dev     # concurrently: css:dev (chokidar → src/build) + js:dev (esbuild --dev)
yarn build   # js:prod + css:prod → app/assets/ (release artifacts)
```

Keep `yarn dev` running in a terminal while editing JS/CSS in `src/`.

### Running tests

Tests use [Appraisal](https://github.com/thoughtbot/appraisal). Gemfiles:
`rails_7`, `rails_8.0`, `rails_8.1`, and `postgres` (some concurrency tests skip
unless run under PostgreSQL, e.g. invite token row locks).

```bash
bundle exec appraisal rake test                 # unit + integration, one rails version
bundle exec appraisal rails-8.1 rake test
bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/policy_test.rb
```

Task layout (`Rakefile`): `rake test` **excludes** `test/system` and
`test/generators`. Generator tests run via `rake test_generators`; system tests
via `rake test:system`; `rake test_all` runs `test` + `test_generators`.

**Schema/working-tree hazard: stage dummy edits before running generator tests.**
Generator tests call `git_restore_dummy_app` in `setup`
(`test/support/generator_test_helper.rb`), which runs `git checkout -- test/dummy`
**and** `git clean -fd test/dummy` before every test. `git checkout --` restores
from the index, so **staged** `test/dummy` changes survive but unstaged ones are
reverted; `git clean -fd` **permanently deletes** untracked files under
`test/dummy` with no recovery. Before `rake test_generators` / `rake test:system`,
`git add` any `test/dummy` changes the run depends on, and clear or stash
untracked scratch files there first.

### Worktrees

The long-running dummy servers run the main checkout (master). To exercise code
on a branch in a worktree, boot a fresh server from that worktree directory; a
server started elsewhere is running master's code, not yours.

### Docs

```bash
yarn docs:dev      # localhost:5173 (runs docs:sync-skills first)
yarn docs:build    # must pass; dead internal links fail the build
```

## Code Conventions (project-specific)

Shared Ruby style lives in `~/.claude/CLAUDE.md`. Project-specific rules:

### Policies: gate per-record actions in the policy, not with `condition:`

For a record action whose availability depends on record state, gate it in the
**policy**, not with a `condition: -> { ... }` proc on the `action` declaration:

```ruby
def resend_invite?
  record.unverified?
end
```

A record action's policy method always receives the **instance** (the table binds
`policy_for(record:)` to the row; the show page's `current_policy` is
instance-bound on member routes). So do **not** add a `record.is_a?(Model)` guard
on a record-action method. The class subject only appears on collection routes
(`index`/`new`), where it backs `read?`, `create?`/`new?`, `export_csv?`,
`search?`/`typeahead?`, and resource-action gates (kanban column actions are
auto-registered resource actions). Note `read?` gets the class via `index?` but
the instance via `show?`. Bulk actions are checked per record, not on the class.

**Why:** authorization belongs in the policy (single source of truth). A
`condition:` only hides UI; it does not deny a forced request, which splits the
guard. Keep a defense-in-depth re-check in the interaction's `execute` if desired.

### Generators
- Provide `--dest=` to avoid interactive prompts: `--dest=main_app` for the main
  app, `--dest=<package_name>` for a package.
- Quote shell args with special characters: `'field:type?'`, `'field:decimal{10,2}'`.

## Git, Commits, and Releases

### Conventional commits, including PR titles

Use conventional commits (`type(scope): subject`) for every commit **and** every
PR title. PRs are squash-merged, so the PR title lands on master verbatim with
`(#NN)` appended; a non-conventional title becomes a malformed commit.

**Why:** `git-cliff` generates the changelog and computes the next version from
the commit history. A prose title like "Wizard DSL Updates and Cleanups" is
invisible to the changelog and can throw off version inference.

Check `git log origin/master --oneline` for the scopes in use (`wizard`, `ui`,
`policy`, `positioning`, `generators`, `auth`, `inputs`, `test`, `chore`,
`dashboard`, `i18n`, ...) and match the format when writing a PR title.

### Release process

Publishing happens from a laptop. CI (`.github/workflows/release.yml`) does
**not** push to any registry: when the `vX.Y.Z` tag lands it only cuts the GitHub
Release (notes + built gem attached), so it cannot race the local publish.

```bash
bundle exec rake release:prepare        # or release:prepare[1.2.3]; bump + changelog + assets, commit (no push)
git show                                # review the bump commit
bundle exec rake release:publish        # push gem + npm, then tag + push → CI cuts the Release
```

`release:publish` is idempotent and resumable (skips a gem/npm already live, tags
only if missing). `rake release:version` shows the next version git-cliff would
pick. The bare `rake release` from bundler is neutralized on purpose; use the
`prepare` then `publish` flow.

## Writing Rules (docs, blog posts, skills)

Docs and posts here are read by developers **and** by AI assistants (the
`.claude/skills/` are synced to `docs/public/skills/` and shipped). A wrong
example does not just mislead a reader; it gets reproduced as code.

### Verify every code sample

Never publish a snippet you have not checked against this codebase. The docs have
been wrong before (`as: :phlexi_tag` resolved to `phlexi_tag_tag` and raised;
working values are `:phlexi_render` and `:phlexi`). When a claim is mechanical,
prove it at runtime:

```bash
cd test/dummy && RAILS_ENV=test bin/rails runner 'puts SomeClass.instance_methods.grep(/x/)'
```

### Document behavior, not internals

- Don't declare what is auto-detected. `field :title` matching the detected type
  is dead code.
- **Definition = how a field renders. Policy = whether it appears.** "Only admins
  see this" is `permitted_attributes_for_*`, never a definition line or a
  `condition:`.
- Pages expose the record as `object`, not `resource`.
- Interactions: `attribute :resource` (no `class:`); rescue
  `ActiveRecord::RecordInvalid` around any `create!`/`update!`/`save!`.
- Policies: never put `*_attributes` hashes in `permitted_attributes_for_*`.

### Voice: avoid the machine-generated tells

- **No em dashes.** Use commas, colons, parentheses, or two sentences.
- No "It's not X, it's Y" or "The pitch isn't... The pitch is..." constructions.
- No tidy-summary line after every example.
- No stacked negation before the real claim; no "critically"; no "genuinely".
- Cut a sentence that restates the one before it.

Deliberate parallelism and a stated opinion are fine. The tell is *unearned*
rhetoric, not rhetoric itself.

### Blog mechanics

Posts are markdown in `docs/blog/` with frontmatter (`title`, `titleTemplate`,
`date`, `description`, `author`, `tags`, optional `draft: true`). Put `<BlogMeta />`
under the `#` heading. A title must be legible cold (it travels via RSS and social
with no site name), so include both "Plutonium" and "Rails". The slug must match
the title; renaming the title means renaming the file. A post is distinguished
from a section index by having a `date`. `yarn docs:build` must pass.

### Screenshots

Match the existing ones: 2480px wide (1240 CSS at `deviceScaleFactor: 2`), light
mode, icon rail collapsed (`localStorage.theme = 'light'`,
`localStorage.pu_rail_pinned = 'false'`). Use realistic, distinct data (repeated
generated titles read as broken data). Crop dead space with `magick`. Store under
`docs/public/images/<section>/`.

## Settled Decisions (do not re-litigate)

- **SQLite for the dummy app** across all environments; production is multi-db
  (primary/cache/queue/cable). Postgres is a test-only appraisal for concurrency
  tests, not the app default.
- **Package + portal engine architecture** for multi-tenancy and features. New
  features go in packages, wired through portal engines.
- **Generators-first**: every dummy-app artifact is generated, then customized.
- **The SaaS post-login flow ships as `pu:saas:welcome`** (welcome controller +
  onboarding/entity-selection views + Rodauth redirects). This bridges
  login → invite check → onboarding → entity selection → portal. It is built; do
  not re-plan it.

## Skills System

`.claude/skills/` holds the AI-assistant skills. They are synced into
`docs/public/skills/` by `yarn docs:sync-skills` (run automatically by
`docs:dev` / `docs:build`) and shipped with the docs. Update the relevant skill
when you change related behavior; skills require a gem release to take effect for
consumers.

## Adding Features

### New field type
1. Renderer in `lib/plutonium/ui/display/components/`
2. Input in `lib/plutonium/ui/form/components/`
3. Register in field-type mappings
4. Tests and docs

### New generator
1. Create in `lib/generators/pu/<category>/<name>_generator.rb`
2. Templates in `lib/generators/pu/<category>/<name>/templates/`
3. Tests in `test/generators/`
4. Document in `docs/reference/generators/`

### New interaction response
1. Response class in `lib/plutonium/interaction/response/`
2. Helper on `Plutonium::Interaction::Outcome::Success`
3. Document usage

## Key Files Reference

| Purpose | Location |
|---------|----------|
| Gem version | `lib/plutonium/version.rb` |
| Main entry | `lib/plutonium.rb` |
| Configuration | `lib/plutonium/configuration.rb` |
| Base controller | `lib/plutonium/resource/controller.rb` |
| Base policy | `lib/plutonium/resource/policy.rb` |
| Base definition | `lib/plutonium/resource/definition.rb` |
| Interactions | `lib/plutonium/interaction/base.rb` |
| Generators | `lib/generators/pu/` |
| Release automation | `lib/tasks/release.rake` |
| Dummy DB config | `test/dummy/config/database.yml` |
| Generator test helper | `test/support/generator_test_helper.rb` |
