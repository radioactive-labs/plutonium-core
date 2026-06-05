# Generators

Plutonium's `pu:*` CLI generators. Discoverable via `rails g pu:<tab>`. Always pass `--dest=` to skip prompts.

## Catalog

| Generator | Purpose |
|---|---|
| [`pu:core:install`](#pu-core-install) | Initial Plutonium setup (base classes, config, layouts) |
| [`pu:core:assets`](#pu-core-assets) | Set up custom Tailwind + Stimulus toolchain |
| [`pu:res:scaffold`](#pu-res-scaffold) | New resource (model, migration, controller, policy, definition) |
| [`pu:res:conn`](#pu-res-conn) | Connect a resource to a portal |
| [`pu:pkg:package`](#pu-pkg-package) | New feature package |
| [`pu:pkg:portal`](#pu-pkg-portal) | New portal package |
| [`pu:rodauth:install`](#pu-rodauth-install) | Install Rodauth base |
| [`pu:rodauth:account`](#pu-rodauth-account) | Basic Rodauth account |
| [`pu:rodauth:admin`](#pu-rodauth-admin) | Hardened admin account (2FA, lockout, audit) |
| [`pu:saas:setup`](#pu-saas-setup) | **Meta** — user + entity + membership + portal + profile + welcome + invites |
| [`pu:saas:user`](#individual-saas-generators) | Individual: SaaS user account |
| [`pu:saas:entity`](#individual-saas-generators) | Individual: entity model |
| [`pu:saas:membership`](#individual-saas-generators) | Individual: membership join model |
| [`pu:saas:portal`](#individual-saas-generators) | Individual: entity-scoped portal |
| [`pu:saas:welcome`](#individual-saas-generators) | Individual: onboarding / select-entity flow |
| [`pu:saas:api_client`](#pu-saas-api-client) | API client for M2M auth |
| [`pu:profile:install`](#pu-profile-install) | Profile resource + security section |
| [`pu:profile:setup`](#pu-profile-setup) | Meta — `pu:profile:install` + `pu:profile:conn` |
| [`pu:profile:conn`](#pu-profile-conn) | Connect profile to a portal as a singular resource |
| [`pu:invites:install`](#pu-invites-install) | User invitations package |
| [`pu:invites:invitable`](#pu-invites-invitable) | Mark a model as invitable |
| [`pu:eject:layout`](#pu-eject-layout) | Eject base layout for customization |
| [`pu:eject:shell`](#pu-eject-shell) | Eject topbar/sidebar partials |
| [`pu:test:install`](#pu-test-install) | Install `Plutonium::Testing` scaffolding |
| [`pu:test:scaffold`](#pu-test-scaffold) | Scaffold integration tests per (resource × portal) |
| [`pu:core:update`](#pu-core-update) | Update plutonium gem + npm package |
| [`pu:skills:sync`](#pu-skills-sync) | Sync Plutonium Claude skills into the project |

::: tip Unattended mode
All generators block on prompts by default. Pass `--dest=`, `--auth=`, `--force`, `--skip-bundle`, `--quiet` etc. to run in scripts/CI. See [App › Unattended execution](./index#unattended-execution).
:::

---

## Resource generators

### `pu:res:scaffold`

Generate a complete resource: model, migration, controller, policy, definition.

```bash
rails g pu:res:scaffold Post user:belongs_to title:string 'content:text?' --dest=main_app
```

| Option | Description |
|---|---|
| `--dest=NAME` | Destination package (`main_app` or `<package>`) — required for unattended runs |
| `--no-model` | Skip model file (for existing models) |
| `--no-migration` | Skip migration (use with `--no-model` for existing schema) |

Field type syntax — full reference in [Resource › Model](/reference/resource/model). Quick recap:

```bash
'name:string'              # required string
'name:string?'             # nullable
'company:belongs_to'       # association
'parent:belongs_to?'       # nullable association
'email:string:uniq'        # with unique index
'amount:decimal{10,2}'     # decimal with precision
'status:string{default:draft}'   # with default value
'metadata:jsonb{default:{}}'     # JSON default
```

Quote any field containing `?` or `{}` to prevent shell expansion.

### `pu:res:conn`

Connect a resource to a portal. Generates portal-specific controller, policy, definition + route registration.

```bash
rails g pu:res:conn Post Comment Tag --dest=admin_portal
rails g pu:res:conn Blogging::Post --dest=admin_portal      # namespaced
rails g pu:res:conn Profile --dest=customer_portal --singular  # singleton
```

| Option | Description |
|---|---|
| `--dest=PORTAL` | Target portal (required) |
| `--singular` | Register as singular resource (`/profile`, no `:id`, no index) |

::: tip Run after migrations
The generator reads model columns to seed the policy's `permitted_attributes_for_*`.
:::

See [Portals › Connecting resources](./portals#connecting-resources-pu-res-conn) for full details.

---

## Package generators

### `pu:pkg:package`

Feature package — models, policies, definitions, interactions.

```bash
rails g pu:pkg:package blogging
```

See [Packages › Feature packages](./packages#feature-packages).

### `pu:pkg:portal`

Portal package — controllers, views, routes, auth.

```bash
rails g pu:pkg:portal admin --auth=user
rails g pu:pkg:portal admin --auth=admin --scope=Organization
```

| Option | Description |
|---|---|
| `--auth=NAME` | Rodauth account to authenticate with |
| `--public` | Public access (no auth) |
| `--byo` | Bring your own auth |
| `--scope=CLASS` | Entity class for multi-tenancy |

See [Portals › Creating a portal](./portals#creating-a-portal).

---

## Authentication generators

### `pu:rodauth:install`

Install the Rodauth base — Roda app, base plugin, controller, layout, PostgreSQL extension migration.

```bash
rails g pu:rodauth:install
```

### `pu:rodauth:account`

Basic Rodauth account with configurable features.

```bash
rails g pu:rodauth:account user                  # interactive
rails g pu:rodauth:account user --defaults       # standard features
rails g pu:rodauth:account user --kitchen_sink   # ALL features
rails g pu:rodauth:account api_user --api_only --jwt --jwt_refresh
```

For full option tables (features, defaults, individual feature flags) see [Auth › Accounts](/reference/auth/accounts).

### `pu:rodauth:admin`

Hardened admin account — pre-configured with multi-phase login, required TOTP, recovery codes, lockout, active sessions, audit logging, role-based access, invite interaction, and **no public signup**.

```bash
rails g pu:rodauth:admin admin
rails g pu:rodauth:admin admin --roles=super_admin,admin,viewer
rails g pu:rodauth:admin admin --extra-attributes=name:string,department:string
```

| Option | Default | Description |
|---|---|---|
| `--roles` | `super_admin,admin` | Comma-separated roles (positional enum, index 0 most privileged) |
| `--extra_attributes` | | Additional model attributes |

Creates a rake task for account creation:

```bash
rails rodauth_admin:create[admin@example.com,password123]
```

---

## SaaS generators

### `pu:saas:setup`

**Meta-generator.** Creates the user + entity + membership trio AND runs:

- `pu:saas:portal` → entity-scoped `{Entity}Portal`
- `pu:profile:setup` → profile model + association
- `pu:saas:welcome` → onboarding / select-entity flow
- `pu:invites:install` → invitations package

```bash
rails g pu:saas:setup --user Customer --entity Organization
rails g pu:saas:setup --user Customer --entity Organization --roles=admin,member
rails g pu:saas:setup --user Customer --entity Organization --no-allow-signup
rails g pu:saas:setup --user Customer --entity Organization \
  --user-attributes=name:string --entity-attributes=slug:string
```

| Option | Default | Description |
|---|---|---|
| `--user=NAME` | (required) | User account model name |
| `--entity=NAME` | (required) | Entity model name |
| `--allow-signup` | `true` | Allow public registration |
| `--roles` | `admin,member` | Additional roles — **`owner` always prepended as index 0** |
| `--skip-entity` | | Skip entity model generation |
| `--skip-membership` | | Skip membership model generation |
| `--user-attributes` | | Additional user model attributes |
| `--entity-attributes` | | Additional entity model attributes |
| `--membership-attributes` | | Additional membership model attributes |
| `--api_client=NAME` | | Also generate an API client model |
| `--api_client_roles` | `read_only,write,admin` | API client roles |

::: warning Don't re-run pieces manually
`pu:saas:setup` chains four other generators. Don't re-run portal / profile / welcome / invites separately after this. Pass `--force` to re-run the whole thing.
:::

### Individual SaaS generators

For when you don't want the full `pu:saas:setup` meta-generator:

```bash
rails g pu:saas:user Customer
rails g pu:saas:entity Organization --extra-attributes=slug:string
rails g pu:saas:membership --user Customer --entity Organization --roles=admin,member
rails g pu:saas:portal customer --entity Organization
rails g pu:saas:welcome --user Customer --entity Organization
```

### `pu:saas:api_client`

API client account for machine-to-machine authentication. HTTP Basic Auth with auto-generated password.

```bash
rails g pu:saas:api_client ApiClient
rails g pu:saas:api_client ApiClient --entity=Organization
rails g pu:saas:api_client ApiClient --entity=Organization --roles=read_only,write,admin
```

| Option | Default | Description |
|---|---|---|
| `--entity=NAME` | | Entity to scope API clients to |
| `--roles` | `read_only,write,admin` | Available roles |
| `--extra_attributes` | | Additional model attributes |
| `--dest` | `main_app` | Destination package |

CLI creation:

```bash
rake api_clients:create LOGIN=my-service
rake api_clients:create LOGIN=my-service ORGANIZATION=acme ROLE=write
```

::: warning Credentials shown once
The auto-generated password is displayed once at creation and cannot be retrieved later (`SecureRandom.base64(32)`).
:::

---

## Profile generators

See [Auth › Profile](/reference/auth/profile) for the full profile feature.

### `pu:profile:install`

Generate the profile resource (model, migration, controller, policy, definition) and modify the user model to add `has_one :profile`.

```bash
rails g pu:profile:install bio:text avatar:attachment 'timezone:string?' --dest=customer
rails g pu:profile:install AccountSettings bio:text --dest=main_app   # custom resource name
```

| Option | Default | Description |
|---|---|---|
| `--dest=DEST` | (prompts) | Target package or `main_app` |
| `--user-model=NAME` | `User` | Rodauth user model |

### `pu:profile:setup`

Meta — runs `pu:profile:install` + `pu:profile:conn` in one shot.

```bash
rails g pu:profile:setup date_of_birth:date bio:text \
  --dest=competition \
  --portal=competition_portal
```

### `pu:profile:conn`

Connect the profile resource to a portal as a **singular** resource (registers `/profile` and the `profile_url` helper).

```bash
rails g pu:profile:conn --dest=customer_portal
```

---

## Invite generators

See [Tenancy › Invites](/reference/tenancy/invites) for the full invitation system.

### `pu:invites:install`

```bash
rails g pu:invites:install
rails g pu:invites:install --entity-model=Organization --user-model=Customer --invite-model=OrganizationInvite
```

| Option | Default | Description |
|---|---|---|
| `--entity-model=NAME` | `Entity` | Entity model name |
| `--user-model=NAME` | `User` | User model name |
| `--invite-model=NAME` | `<EntityModel><UserModel>Invite` | Invite class name |
| `--membership-model=NAME` | `EntityUser` | Membership join model (must already exist; roles read from its `enum :role`) |
| `--rodauth=NAME` | `user` | Rodauth configuration for signup |
| `--enforce-domain` | `false` | Require email domain to match entity |
| `--dest=PACKAGE` | `main_app` | Package where the entity model lives (controls where `invite_user_interaction.rb` is generated) |

Multiple invite flows are supported — run `pu:invites:install` once per flow.

### `pu:invites:invitable`

Mark an app model as invitable (gets notified when an invite is accepted via `on_invite_accepted`).

```bash
rails g pu:invites:invitable Tenant
rails g pu:invites:invitable TeamMember --role=member
rails g pu:invites:invitable Tenant --dest=my_package
```

| Option | Default | Description |
|---|---|---|
| `--role=ROLE` | `member` | Role to assign to invited users |
| `--user-model=NAME` | `User` | User model |
| `--membership-model=NAME` | `EntityUser` | Membership join model |
| `--dest=PACKAGE` | `main_app` | Destination package |
| `--[no-]email-templates` | `true` | Generate custom email templates |

---

## Core generators

### `pu:core:install`

Initial Plutonium setup. Creates base classes, config initializer, layouts. Run once per app.

```bash
rails g pu:core:install
```

### `pu:core:assets`

Set up the custom Tailwind + Stimulus toolchain. Installs npm packages, creates `tailwind.config.js`, imports Plutonium CSS, registers Stimulus controllers.

```bash
rails g pu:core:assets
```

See [UI › Assets](/reference/ui/assets) for what gets configured.

### `pu:core:update`

Update the plutonium gem and npm package together.

```bash
rails g pu:core:update
```

---

## Eject generators

### `pu:eject:layout`

Copy the base layout template into your portal for direct editing.

```bash
rails g pu:eject:layout
```

### `pu:eject:shell`

Copy the topbar/sidebar partials into your portal for direct editing.

```bash
rails g pu:eject:shell --dest=admin_portal
```

See [UI › Layouts](/reference/ui/layouts).

---

## Test generators

See [Testing](/reference/testing/) for the full testing toolkit.

### `pu:test:install`

Install the testing scaffolding (require `plutonium/testing` in `test_helper.rb`; create `test/support/plutonium_testing.rb` for overrides). Run once.

```bash
rails g pu:test:install
```

### `pu:test:scaffold`

Scaffold integration tests — one file per (resource × portal) pairing.

```bash
rails g pu:test:scaffold Blogging::Post --portals=admin,org
rails g pu:test:scaffold Blogging::Post --portals=admin --concerns=crud,policy,definition
rails g pu:test:scaffold Blogging::Post --portals=org --parent=organization --dest=blogging
```

| Option | Default | Description |
|---|---|---|
| `--portals=admin,org` | (required) | Emit one file per portal |
| `--concerns=...` | `crud,policy,definition` | Concerns to include (full list: `crud,policy,definition,nested,model,interaction,portal_access`) |
| `--parent=organization` | | Wires the `NestedResource` parent |
| `--dest=...` | `main_app` | Output destination |

---

## Skill generators

### `pu:skills:sync`

Sync Plutonium's Claude Code skills into the project (`.claude/skills/`). Run when upgrading the gem.

```bash
rails g pu:skills:sync
```

---

## Common workflows

### Full app setup

```bash
# 1. Plutonium template (greenfield) — does all initial setup
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb

# Or for existing app:
rails generate pu:core:install
rails generate pu:rodauth:install

# 2. Account types
rails generate pu:rodauth:admin admin
# (or pu:saas:setup for multi-tenant)

# 3. Resources
rails generate pu:res:scaffold Post title:string body:text --dest=main_app
rails generate pu:res:scaffold Comment body:text post:belongs_to --dest=main_app

# 4. Portal
rails generate pu:pkg:portal admin --auth=admin

# 5. Connect resources
rails generate pu:res:conn Post Comment --dest=admin_portal

# 6. Migrate
rails db:prepare

# 7. Create the first admin
rails rodauth_admin:create[admin@example.com,password123]
```

### Adding a new resource

```bash
rails g pu:res:scaffold Product name:string price_cents:integer --dest=main_app
rails db:prepare
rails g pu:res:conn Product --dest=admin_portal
```

### Adding a new portal

```bash
rails g pu:pkg:portal customer --auth=user --scope=Organization
rails g pu:res:conn Order --dest=customer_portal
rails db:prepare
```

## Undoing generators

```bash
rails destroy pu:res:scaffold Post
rails destroy pu:pkg:portal admin
```

## Troubleshooting

### Generator not found

Ensure Plutonium is installed and bundle is up to date:

```ruby
# Gemfile
gem "plutonium"
```

```bash
bundle install
```

### Package not found

Generators run from Rails root. Package names are case-sensitive.

### Migration already exists

If a migration with the same timestamp exists, wait a second and retry — Rails generates timestamps to one-second resolution.

## Related

- [Packages](./packages) — feature vs portal package structure
- [Portals](./portals) — portal configuration and resource connection
- [Resource › Model](/reference/resource/model) — field-type syntax for `pu:res:scaffold`
- [Auth](/reference/auth/) — account type configuration
- [Tenancy](/reference/tenancy/) — multi-tenancy and invitations
- [Testing](/reference/testing/) — test scaffolding
