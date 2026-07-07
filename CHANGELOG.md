# Changelog

All notable changes to this project will be documented in this file.

## [0.62.1] - 2026-07-07

### Bug Fixes

- Split grouped error classes into per-constant files
- Fall back to index when deleting from the record's own page

### Documentation

- Add SECURITY.md and auto-bump its version series on release

### Miscellaneous Tasks

- Require RubyGems MFA and disable CI auto-release

## [0.62.0] - 2026-07-04

### Bug Fixes

- Run input-less column actions directly instead of an empty modal
- Don't call signed_id on an unsaved ActiveStorage blob in uppy
- Active_shrine downstream fixes — mime-types gem + resource param double-read
- Stop the board blanking on search/filter/scope
- Size currency input padding to its unit prefix
- Preserve collapse + horizontal scroll across moves and refresh
- Give the body a base text color so unstyled text stays visible
- Give modal dialogs a base text color so unstyled text stays visible

### Features

- AI agent on-ramp — llms.txt, /ai quickstart, crawlable skills
- Type-aware kanban meta badges + has_cents currency unit
- Expose intl-tel-input options + default_phone_country config
- Currency input + currency/choice-aware wizard review summary
- Add :lost terminal column role
- Keep the board fresh + scrolled across writes and actions
- [**breaking**] Drop interactions, immediate drops, on_exit + on_drop→on_enter rename ([#67](https://github.com/radioactive-labs/plutonium-core/issues/67))

### Refactoring

- Server-read collapse cookie + stable frame placeholders

## [0.61.0] - 2026-06-30

### Bug Fixes

- Animate the dialog scale pop via the `scale` property
- Normalize mixed-case logins to lowercase on input
- Normalize invite email to lowercase at the source
- Downcase login in signup handler's existing-account guard
- Rescue DeleteRestrictionError in CRUD destroy
- Keep modal dialogs transform-free so fixed overlays escape the panel
- Render the classic shell sidebar again
- Mount uppy Dashboard into the modal dialog so it renders above it
- Coerce ActiveStorage::Filename to String for HTML title attributes ([#66](https://github.com/radioactive-labs/plutonium-core/issues/66))
- Bump dompurify to 3.4.11 and esbuild to 0.28.1 to clear npm audit
- Clear npm Dependabot alerts (lodash 4.18.1 + dev-tree dedupe)

### Features

- Omit empty Details tab when no fields are permitted
- Mask password/secret fields so the stored value never reaches the DOM
- Plutonium::Wizard — declarative multi-step wizard subsystem ([#62](https://github.com/radioactive-labs/plutonium-core/issues/62))
- Kanban board DSL — first-class index view with drag-to-move ([#63](https://github.com/radioactive-labs/plutonium-core/issues/63))

### Miscellaneous Tasks

- Make releasing laptop-driven and race-free
- Review before commit — prepare stages, publish commits

### Refactoring

- Drop the current_<name> alias from the rodauth mixin

### Wizard

- Docs accuracy + completeness audit, plus a per-field Shrine uploader for attachments ([#64](https://github.com/radioactive-labs/plutonium-core/issues/64))

## [0.60.5] - 2026-06-30

### Bug Fixes

- Coerce ActiveStorage::Filename to String for HTML title attributes

### Miscellaneous Tasks

- Update yarn.lock and .yarnrc.yml after yarn install

## [0.60.4] - 2026-06-15

### Features

- Drop the section divider rule, keep the accent bar

## [0.60.3] - 2026-06-15

### Features

- Drop form_layout sections that resolve to zero fields
- Refine form_layout section header styling

### Refactoring

- Move engine shell to Portal::Engine with live cascade

## [0.60.2] - 2026-06-15

### Features

- Resolve shell across global, engine, and controller tiers

## [0.60.1] - 2026-06-15

### Bug Fixes

- Skip section fields not in the permitted set instead of raising

### Features

- First-class railless portal support

## [0.60.0] - 2026-06-14

### Features

- Add resend-invite action to rodauth admin
- Form sectioning DSL (form_layout / section / ungrouped) ([#61](https://github.com/radioactive-labs/plutonium-core/issues/61))

## [0.59.0] - 2026-06-13

### Bug Fixes

- Configure solid_errors reading connection and env lookup
- Resolve association filter class via resource_class reflection

### Features

- Add built-in policy-gated CSV export

## [0.58.1] - 2026-06-10

### Bug Fixes

- Prevent pu-rail-pinned persisting on non-rail pages

## [0.58.0] - 2026-06-10

### Bug Fixes

- Set url_options directly on ActionMailer::Base instead of config
- Short-circuit call with failure when validation fails
- Pre-populate extraction record so conditioned selects resolve correctly
- Use after_commit to avoid orphaned email jobs on rollback

## [0.57.0] - 2026-06-09

### Bug Fixes

- Guard tailwind prerequisite and fix landing page command
- Guard against nil current_scoped_entity in remember_scoped_entity
- Use dynamic viewport height to prevent clipping on mobile

### Features

- Add display-only condition: to scopes

### Miscellaneous Tasks

- Add skill sync to plutonium template and use conventional commits

## [0.56.3] - 2026-06-07

### Bug Fixes

- Use dynamic viewport height so mobile rail toggle stays visible
- Link icon rail logo to home
- Default icon rail to pinned
- Let scopes bar scroll horizontally on small screens

## [0.56.2] - 2026-06-05

### Bug Fixes

- Run skills sync in unbundled env
- Prevent large page numbers from overflowing buttons

## [0.56.1] - 2026-06-05

### Bug Fixes

- Version-adapt kitchen_sinks migration

### Documentation

- Recommend db:prepare, firm up README, document conditional actions

### Features

- Add display-only condition: to actions

## [0.56.0] - 2026-06-05

### Bug Fixes

- Sync skills in a fresh process; pin post-install notice to 0.49.0
- Native multi-selects render at a usable height
- Dropdown menu teleports to <body> to escape overflow clipping
- Force :resources route_type for has_many nested routes
- Record-scoped commit URL for actions with record_action: false
- Serialize JSON values via as_json (ISO 8601 datetimes)
- Add reading role to Rails Pulse connects_to config
- Bind subject during interaction param extraction
- Dirty-form-guard tracks edits via first-interaction baseline
- Give the JSON form input dark-mode styling

### Features

- Auto-rendered components for boolean, enum & money fields
- Add pu:lite:tune and pu:lite:maintenance for SQLite tuning + maintenance
- Sidebar menu items accept arbitrary link attributes
- Restore deleted nested rows + shared, polished removed bar
- Type-aware grid cards + overhaul KitchenSink dummy resource

### Miscellaneous Tasks

- Sync appraisal gemfile.lock files to v0.55.0

### Testing

- Fix stale generator assertions and drop committed dummy schema
- Add KitchenSink resource exercising every input/display type

## [0.55.0] - 2026-06-03

### Bug Fixes

- Keep modal backdrop static to smooth dialog dismiss

### Features

- Structured_input — classless structured & repeater inputs (resources + interactions) ([#60](https://github.com/radioactive-labs/plutonium-core/issues/60))

### Testing

- Land authenticated users on the entity-scoped org portal
- Serve the Organization resource in the org portal

## [0.54.0] - 2026-06-01

### Bug Fixes

- Match Plutonium::Engine by name to survive dev reload
- Carry only an explicit return_to on resource forms
- Ignore bubbled file-input cancel in modal dialogs
- Cap icon-rail flyout to the viewport height

### Features

- Refine file-input height and required-marker theming

### Miscellaneous Tasks

- Rebuild bundled assets

### Refactoring

- Render flash via self-contained component classes

### Testing

- Characterize nested resource and interaction form rendering

## [0.53.1] - 2026-05-31

### Bug Fixes

- Tolerate non-Plutonium engines during route reload

## [0.53.0] - 2026-05-31

### Bug Fixes

- Correct broken cross-page anchors in guides
- Retract incorrect "never super" guidance in relation_scope
- Correct scoped-URL shape in multi-tenancy docs
- Match change_password_notify mailer template name

### Features

- Add Avatar component with Navii fallback ([#59](https://github.com/radioactive-labs/plutonium-core/issues/59))

### Refactoring

- Remove dead view helpers superseded by Phlex components

## [0.52.0] - 2026-05-21

### Bug Fixes

- Use inclusion validation for required booleans
- Warn on failed yarn add instead of silently continuing
- Let StopWriting terminals scroll horizontally instead of overflowing the column
- Drop misleading 15-min claim — hero CTA → 'Tutorial', getting-started title → 'Learn Plutonium by building'
- Tutorial walkthrough + reference audit ([#57](https://github.com/radioactive-labs/plutonium-core/issues/57))
- Scope form ids per turbo frame to prevent stream-replace collisions
- Hide secure_association "+" inside secondary modal
- Dedupe pre_submit hidden field on repeat change events
- Form error alert margin + include model name in New/Edit page titles

### Miscellaneous Tasks

- Refresh rails-8.1 gemfile.lock for v0.51.0

## [0.51.0] - 2026-05-14

### Bug Fixes

- Stabilize generator test suite against hangs
- Validate association SGIDs against full authz scope
- Keep yarn out of the parent TTY

### Documentation

- Restructure into 7 functional areas + rewrite guides as task recipes

### Features

- Stack secondary modal for inline "+" on associations
- Json/jsonb input component with raw-value support
- Typeahead endpoint for resource form inputs and filters ([#55](https://github.com/radioactive-labs/plutonium-core/issues/55))

### Miscellaneous Tasks

- Bump frontend deps to clear Dependabot alerts
- Bump appraisal lockfiles to 0.50.0
- Drop dead pin_shell_to_classic hook

### Refactoring

- Rename views DSL to index_views
- Compact and merge 19 skills into 8

## [0.50.0] - 2026-05-11

### Bug Fixes

- Suppress label and chrome for hidden fields
- Inject recurring tasks under env blocks

### Features

- Style WebKit autofill on .pu-input variants

## [0.49.1] - 2026-05-06

### Bug Fixes

- Scope parent association only to matching relations
- Preserve sidebar scroll across Turbo navigations
- Add invite_entity_attribute hook for non-:entity invite models
- Restore default layout on direct loads
- Unblock acceptance + non-importmap apps
- Force text/html on failure response
- Position calendar correctly inside modal dialogs

### Features

- Support multiple invite models per app

## [0.49.0] - 2026-05-04

### Bug Fixes

- Return clean 403 from non-HTML unauthorized handler
- Align pu:lite:rails_pulse with v0.3 schema flow
- Prefer main_app.root_path over login_redirect

### Features

- Add `pu:gem:actual_db_schema` and wire into app template
- Add auto mode to color mode selector
- Render color mode selector on rodauth layout
- Flesh out rails_pulse initializer template

### Miscellaneous Tasks

- Rename :client_max_limit to :max_limit
- Run appraisals

### Refactoring

- Rename entity scope prefix from `_scope` to `_scoped`

## [0.48.0] - 2026-04-16

### Bug Fixes

- Respect `confirmation: false` on interactive actions

### Features

- Preserve scroll by emitting refresh when redirect target matches referer

### Testing

- Browser coverage for Turbo refresh + scroll preservation

## [0.47.0] - 2026-04-15

### Features

- Add `interaction:` kwarg to resource_url_for
- Add Plutonium::Testing module, generators, skill, docs, and migrate in-repo tests

### Miscellaneous Tasks

- Update yarn

## [0.46.0] - 2026-04-11

### Bug Fixes

- Resolve scoped entity class lazily to survive autoreload
- Render page title in layout, drop per-view h1s
- Use derived user association in current_membership
- Redirect to login after verification email sent

### Documentation

- Clarify generator gotchas for installation, rodauth, and unattended runs
- Comprehensive Plutonium skills overhaul
- Document nested_attributes gotchas in policy and definition

### Features

- Default profile model to {UserModel}Profile
- Sync skills during pu:core:update if plutonium skill is installed
- Disable Active Storage railtie and include ActiveShrine::Model

### Miscellaneous Tasks

- Update test lockfiles

### Refactoring

- Add inject_into_concerns_controller to merge included blocks

## [0.45.3] - 2026-04-07

### Bug Fixes

- Use Pagy::OPTIONS instead of frozen DEFAULT

## [0.45.2] - 2026-04-07

### Bug Fixes

- Honor limit param by setting client_max_limit

## [0.45.1] - 2026-04-02

### Bug Fixes

- Use named route helpers for top-level resource URLs

## [0.45.0] - 2026-04-01

### Bug Fixes

- Suffix scoped_entity_param_key to prevent route param collision
- Add view path and fix nested form in invitation template

### Features

- Add entity link to portal resource header
- Add --pu-text-danger CSS token

### Refactoring

- Consolidate skills and improve discoverability

## [0.44.1] - 2026-03-30

### Bug Fixes

- Register rescue responses before action_dispatch.configure
- Pass association SGIDs in create params to match form submission

### Miscellaneous Tasks

- Bump phlexi-form to >= 0.14.2

### Refactoring

- Use upstream @raw_choices from phlexi-form 0.14.2

## [0.44.0] - 2026-03-30

### Bug Fixes

- Lazy-load sequel to avoid requiring it when Rodauth is unused

### Features

- Support singular parent resources and entity scoping in nested URL generation
- Add pu:saas:welcome generator for post-login onboarding
- Extend pu:saas:setup with portal, welcome, invites, and profile

### Refactoring

- Upgrade pagy from v9 to v43
- Improve SaaS generators and shared concerns
- Improve welcome flow, idempotent routes, and skip action
- Add non-interactive prompt, improve build tooling and association resolver
- Restructure dummy app with catalog, multi-portal architecture

## [0.43.2] - 2026-03-13

### Bug Fixes

- Use enum name for status and correct interaction base class

### Miscellaneous Tasks

- Fix generator assertions and remove dead code
- Remove trailing blank line in model_generator_base
- Update Ruby to 3.4 and refresh dependencies

### Refactoring

- Extract current_policy_context to base authorizable
- Use Rodauth module include and remove dead code

## [0.43.1] - 2026-03-09

### Bug Fixes

- Fix scope comparison and clean up scopes bar component
- Auto-run npm login instead of aborting on missing auth

## [0.43.0] - 2026-03-05

### Bug Fixes

- Support custom primary keys and optional timestamps
- Handle singular resources and entity scoping correctly
- Improve robustness and package support
- Handle class reloading in associated_with scope
- Show profile link in user menu only when profile_url defined
- Fix invites templates and null attribute handling

### Documentation

- Add profile guide and update skill documentation

### Features

- Add TypeSpec API specification generator
- Make submit_and_continue button configurable
- Add package destination and namespace handling to invites
- Auto-detect entity association by class
- Add profile generators for user settings pages
- Add profile_url helper method to rodauth module

### Miscellaneous Tasks

- Add profile_url stub to controller template and test fixtures

### Refactoring

- Extract breadcrumb rendering methods and add tests

### Testing

- Add OrgPortal fixture for entity scoping tests
- Add tests for routing, authorization, and display helpers

## [0.42.0] - 2026-02-14

### Documentation

- Update generator documentation and improve saas generators

### Features

- Add clipboard controller and fix modal scroll lock
- Add turbo stream support to render response
- Add scoping concern for entity/parent access
- Enhance rodauth generators
- Add API client generator for SaaS apps

### Miscellaneous Tasks

- Update gemfile locks

### Refactoring

- Consolidate generator test cleanup with git restore

### Testing

- Add unit tests for api client and response concerns

## [0.41.1] - 2026-02-09

### Features

- Support JSON default values for jsonb fields

## [0.41.0] - 2026-02-09

### Bug Fixes

- Fix has_many association injection pattern
- Add missing scripts to package.json in assets generator
- Remove primary account support for rodauth
- Use top-level Gem::Version to avoid namespace collision
- Check resource registration before generating association add URL

### Documentation

- Add class_name option and associations section to generator docs

### Features

- Add default value support and improve SQLite compatibility
- Add class_name option for belongs_to fields
- Add --policy and --definition flags to conn generator

### Testing

- Add tests for named rodauth account configuration
- Move type alias tests to core and test actual migrations

## [0.40.0] - 2026-02-04

### Bug Fixes

- Scope load_memory to account-specific paths
- Resolve Thor invoke caching in entity generator
- Use dynamic migration versioning for Rails compatibility
- Wrap SQLite alias in defined? check for compatibility
- Add variants to product policy permitted attributes
- Improve has_one url assertion in resource_url_for test
- Normalize CamelCase package names and validate resource records
- Dedupe namespace and read model attrs with --no-model
- Use local gem path when LOCAL=1
- Guard against envs gems during template execution
- Run db:prepare after config in lite generators
- Restore ResourceController to portal generator

### Documentation

- Add invites skill and update rodauth skill
- Add user invites guide

### Features

- Add user invitation system for multi-tenant apps
- Add roles and extra_attributes options to rodauth generators
- Add --scope flag to portal generator for entity scoping
- Add --singular flag to pu:res:conn for singular resources
- Add pu:lite namespace for SQLite-based services
- Add pu:saas namespace for multi-tenant SaaS setup
- Add default_scope method for setting default query scope

### Miscellaneous Tasks

- Update gemfile locks
- Remove old assets

### Refactoring

- Comment out default policy methods

### Testing

- Add tests for rodauth and invites generators

## [0.39.2] - 2026-01-27

### Bug Fixes

- Handle create and update nested routes

## [0.39.1] - 2026-01-26

### Bug Fixes

- Include ImageTag helper for AssetsHelper compatibility

## [0.39.0] - 2026-01-26

### Bug Fixes

- Remove duplicate kv store controller and move improvements into original
- Improve association filter class resolution
- Improve dropdown positioning with viewport boundary
- Dynamically detect database adapter for Rodauth ([#51](https://github.com/radioactive-labs/plutonium-core/issues/51))
- Use correct action attributes for form re-rendering on errors
- Distinguish empty vs not-submitted key-value store fields
- Use existing record context for form param extraction
- Prevent UrlGenerationError when extracting params for nested resource update
- Correct URL generation for interactive actions on nested resources
- Replace deprecated phlex-rails `helpers` method with `view_context`
- Add named routes for commit actions and document route naming requirement

### Documentation

- Document formatter option for columns and displays
- Cleanup review definition
- Add troubleshooting guide for inflection issue
- Update nested resource routes to use nested_ prefix

### Features

- Handle ActionPolicy::Unauthorized for non-HTML formats
- Add non-HTML response handlers for successful actions
- Add has_one nested resource support
- [**breaking**] Refactor nested resource URL generation with named route helpers
- Add default_relation_scope method with verification
- Use association names for nested resource titles and breadcrumbs

### Miscellaneous Tasks

- Use chokidar to fix dev build cyclic dependency issues
- Warn when running tests without Appraisal
- Switch to yarn
- Update og image

### Testing

- Refactor tests to use real module implementations instead of mocks

## [0.37.0] - 2026-01-21

### Features

- Add textarea auto-grow functionality

### Refactoring

- Migrate slim-select styles to design tokens

## [0.36.0] - 2026-01-21

### Features

- Add pu:core:update to sync gem and npm versions

## [0.35.0] - 2026-01-20

### Bug Fixes

- Use turbo stream redirect action instead of HTTP 302 for form submissions
- Exclude turbo_stream format from URL preservation
- Improve table container scroll and telephone input padding
- Pass unwrapped record into custom column blocks
- Prevent h2 text cutoff in VitePress docs

### Documentation

- Improve interaction docs
- Overhaul README, CONTRIBUTING, and add CLAUDE.md for development
- Redesign landing page with modern layout and AI messaging
- Unify branding and add social preview meta tags
- Fix broken links
- Add Author Portal tutorial chapter
- Fix minimum rails version
- Fix drafts scope for posts
- Remove cookbooks
- Reorganize features section of homepage
- Clean up docs and fix misc issues
- Rewrite theming guide with design tokens and component classes
- Removed potentially misleading section on per portal themes
- Document authorization methods
- Add skills for themeing specifically

### Features

- Add demo_features package and demo_portal for testing
- Implement bulk actions for resource tables
- Modernize UI with design token system and component classes
- Add actions dropdown for secondary and danger actions
- Add form input type aliases for explicit field type declarations
- Add built-in filter types with dropdown filter panel UI
- Add boolean and color components with type aliases
- Add clear all button with filter-panel controller

### Miscellaneous Tasks

- Optimize og graph title and images
- Realign marketing material
- Add seeds for demo models and fix foreign keys
- Standardrb

### Refactoring

- Remove ResourceController from portal generator
- Rename skills with plutonium- prefix to avoid conflicts
- Simplify dashboard templates with design system classes
- Update auth pages with new design tokens

## [0.34.1] - 2026-01-18

### Bug Fixes

- Check npm auth early in release workflow
- Correct generator flags to use --dest instead of --portal/--package

## [0.34.0] - 2026-01-18

### Bug Fixes

- Handle turbo_stream format in CRUD and interactive actions
- Support nullable syntax with type options
- Prevent overwriting existing url_options configuration
- Normalize reference names before comparing namespaces
- Include engine migrations in programmatic migration paths
- Handle missing version tag in next_version task

### Documentation

- Add Claude Code skills and improve generator documentation
- Add definition skills and update module documentation
- Add comprehensive Claude Code skills for resources
- Add package and portal skills
- Add interaction skill for business logic actions
- Add new Claude Code skills and enhance existing ones

### Features

- Configure default_url_options via RAILS_DEFAULT_URL env var
- Add pu:skills:sync to install Claude Code skills
- Execute adhoc blocks in controller context
- Map ActionPolicy::Unauthorized to 403 Forbidden
- Add default scope support for resource queries

### Miscellaneous Tasks

- Overhaul documentation structure and test infrastructure
- Move brakeman config to config/ and update ignore list

### Styling

- Standardrb linting

## [0.33.0] - 2026-01-12

### Revert

- Remove semantic design token system

## [0.32.0] - 2026-01-12

### Bug Fixes

- Move fontFamily to theme root level

## [0.31.0] - 2026-01-12

### Bug Fixes

- Preserve request format in redirects
- Reset policy cache before rendering create response for api calls

### Features

- Add cross-tab color mode synchronization
- Add npm package publishing support
- Add semantic design token system for theming

### Miscellaneous Tasks

- Build assets during prepare phase

## [0.28.0] - 2025-11-12

### Bug Fixes

- Make controller_for inheritable and respect custom inflections

### Features

- Add sgid support and improve association serialization in API

## [0.27.0] - 2025-11-05

### Bug Fixes

- Reload version constant in release:publish task

### Documentation

- Setup contribution guidelines using Conventional Commits

### Features

- Add field-level options support for input/display/column definitions

## [0.26.9] - 2025-09-25

### Features

- Disable csrf protection if authorization header is set

## [0.26.8] - 2025-08-11

### Bug Fixes

- Prevent SQLite adapter error when using non-SQLite databases ([#42](https://github.com/radioactive-labs/plutonium-core/issues/42))
- Fix STI model routing logic in controller ([#43](https://github.com/radioactive-labs/plutonium-core/issues/43))

## [0.26.6] - 2025-08-03

### Refactoring

- Enhance color mode selector and integrate into header layout ([#41](https://github.com/radioactive-labs/plutonium-core/issues/41))

## [0.26.2] - 2025-07-22

### Bug Fixes

- Handle redirect after interaction submission ([#37](https://github.com/radioactive-labs/plutonium-core/issues/37))
- Enhance flatpickr to attach to modals correctly ([#35](https://github.com/radioactive-labs/plutonium-core/issues/35))

## [0.23.2] - 2025-05-27

### Refactoring

- Update EasyMDE styles ([#33](https://github.com/radioactive-labs/plutonium-core/issues/33))

## [0.23.1] - 2025-05-27

### Bug Fixes

- Hide password visibility checkbox when not needed ([#32](https://github.com/radioactive-labs/plutonium-core/issues/32))

## [0.21.1] - 2025-04-27

### Features

- Preserve whitespace in hints to allow some formatting ([#25](https://github.com/radioactive-labs/plutonium-core/issues/25))

### Refactoring

- Fix join condition for `has_one` and `has_many` associations ([#23](https://github.com/radioactive-labs/plutonium-core/issues/23))

## [0.21.0] - 2025-04-01

### Features

- Add cleaner cards for resources on the dashboard index page ([#22](https://github.com/radioactive-labs/plutonium-core/issues/22))

## [0.20.4] - 2025-03-15

### Bug Fixes

- Fix Tailwind CSS v4 upgrade issue for existing projects ([#18](https://github.com/radioactive-labs/plutonium-core/issues/18))

## [0.19.13] - 2025-03-02

### Features

- Add password visibility toggle to sign up and login forms ([#17](https://github.com/radioactive-labs/plutonium-core/issues/17))

## [0.6.2] - 2024-02-21

<!-- generated by git-cliff -->
