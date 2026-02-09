## [0.41.0] - 2026-02-09

### 🚀 Features

- *(generators)* Add default value support and improve SQLite compatibility
- *(generators)* Add class_name option for belongs_to fields
- *(generators)* Add --policy and --definition flags to conn generator

### 🐛 Bug Fixes

- *(generators)* Fix has_many association injection pattern
- *(generators)* Add missing scripts to package.json in assets generator
- *(generators)* Remove primary account support for rodauth
- *(generators)* Use top-level Gem::Version to avoid namespace collision
- *(ui)* Check resource registration before generating association add URL

### 📚 Documentation

- Add class_name option and associations section to generator docs

### 🧪 Testing

- *(generators)* Add tests for named rodauth account configuration
- *(sqlite)* Move type alias tests to core and test actual migrations
## [0.40.0] - 2026-02-04

### 🚀 Features

- *(invites)* Add user invitation system for multi-tenant apps
- *(generators)* Add roles and extra_attributes options to rodauth generators
- *(generator)* Add --scope flag to portal generator for entity scoping
- *(generator)* Add --singular flag to pu:res:conn for singular resources
- *(generators)* Add pu:lite namespace for SQLite-based services
- *(generators)* Add pu:saas namespace for multi-tenant SaaS setup
- *(definition)* Add default_scope method for setting default query scope

### 🐛 Bug Fixes

- *(rodauth)* Scope load_memory to account-specific paths
- *(generators)* Resolve Thor invoke caching in entity generator
- *(test)* Use dynamic migration versioning for Rails compatibility
- *(config)* Wrap SQLite alias in defined? check for compatibility
- *(test)* Add variants to product policy permitted attributes
- *(test)* Improve has_one url assertion in resource_url_for test
- *(generators)* Normalize CamelCase package names and validate resource records
- *(generators)* Dedupe namespace and read model attrs with --no-model
- *(templates)* Use local gem path when LOCAL=1
- *(generators)* Guard against envs gems during template execution
- *(generators)* Run db:prepare after config in lite generators
- *(generators)* Restore ResourceController to portal generator

### 🚜 Refactor

- *(generators)* Comment out default policy methods

### 📚 Documentation

- *(skills)* Add invites skill and update rodauth skill
- *(guides)* Add user invites guide

### 🧪 Testing

- *(generators)* Add tests for rodauth and invites generators

### ⚙️ Miscellaneous Tasks

- Remove old assets
## [0.39.2] - 2026-01-27

### 🐛 Bug Fixes

- Handle create and update nested routes
## [0.39.1] - 2026-01-26

### 🐛 Bug Fixes

- *(ui)* Include ImageTag helper for AssetsHelper compatibility
## [0.39.0] - 2026-01-26

### 🚀 Features

- *(core)* Handle ActionPolicy::Unauthorized for non-HTML formats
- *(interactive_actions)* Add non-HTML response handlers for successful actions
- *(routing)* Add has_one nested resource support
- *(routing)* [**breaking**] Refactor nested resource URL generation with named route helpers
- *(policy)* Add default_relation_scope method with verification
- *(nested)* Use association names for nested resource titles and breadcrumbs

### 🐛 Bug Fixes

- Remove duplicate kv store controller and move improvements into original
- *(filters)* Improve association filter class resolution
- *(ui)* Improve dropdown positioning with viewport boundary
- *(auth)* Dynamically detect database adapter for Rodauth (#51)
- *(crud)* Use correct action attributes for form re-rendering on errors
- *(form)* Distinguish empty vs not-submitted key-value store fields
- *(controller)* Use existing record context for form param extraction
- *(controller)* Prevent UrlGenerationError when extracting params for nested resource update
- *(routing)* Correct URL generation for interactive actions on nested resources
- *(ui)* Replace deprecated phlex-rails `helpers` method with `view_context`
- *(routing)* Add named routes for commit actions and document route naming requirement

### 📚 Documentation

- *(definition)* Document formatter option for columns and displays
- Cleanup review definition
- Add troubleshooting guide for inflection issue
- Update nested resource routes to use nested_ prefix

### 🧪 Testing

- Refactor tests to use real module implementations instead of mocks

### ⚙️ Miscellaneous Tasks

- Use chokidar to fix dev build cyclic dependency issues
- Warn when running tests without Appraisal
- Switch to yarn
- Update og image
## [0.37.0] - 2026-01-21

### 🚀 Features

- *(ui)* Add textarea auto-grow functionality

### 🚜 Refactor

- *(ui)* Migrate slim-select styles to design tokens
## [0.36.0] - 2026-01-21

### 🚀 Features

- *(generators)* Add pu:core:update to sync gem and npm versions
## [0.35.0] - 2026-01-20

### 🚀 Features

- Add demo_features package and demo_portal for testing
- Implement bulk actions for resource tables
- Modernize UI with design token system and component classes
- Add actions dropdown for secondary and danger actions
- Add form input type aliases for explicit field type declarations
- Add built-in filter types with dropdown filter panel UI
- *(display)* Add boolean and color components with type aliases
- *(filters)* Add clear all button with filter-panel controller

### 🐛 Bug Fixes

- Use turbo stream redirect action instead of HTTP 302 for form submissions
- Exclude turbo_stream format from URL preservation
- Improve table container scroll and telephone input padding
- Pass unwrapped record into custom column blocks
- *(docs)* Prevent h2 text cutoff in VitePress docs

### 🚜 Refactor

- Remove ResourceController from portal generator
- Rename skills with plutonium- prefix to avoid conflicts
- Simplify dashboard templates with design system classes
- *(ui)* Update auth pages with new design tokens

### 📚 Documentation

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

### ⚙️ Miscellaneous Tasks

- Optimize og graph title and images
- Realign marketing material
- Add seeds for demo models and fix foreign keys
- Standardrb
## [0.34.1] - 2026-01-18

### 🐛 Bug Fixes

- *(release)* Check npm auth early in release workflow
- *(docs)* Correct generator flags to use --dest instead of --portal/--package
## [0.34.0] - 2026-01-18

### 🚀 Features

- *(generators)* Configure default_url_options via RAILS_DEFAULT_URL env var
- *(generators)* Add pu:skills:sync to install Claude Code skills
- *(query)* Execute adhoc blocks in controller context
- *(railtie)* Map ActionPolicy::Unauthorized to 403 Forbidden
- *(query)* Add default scope support for resource queries

### 🐛 Bug Fixes

- *(controllers)* Handle turbo_stream format in CRUD and interactive actions
- *(generators)* Support nullable syntax with type options
- *(generators)* Prevent overwriting existing url_options configuration
- *(generators)* Normalize reference names before comparing namespaces
- *(package)* Include engine migrations in programmatic migration paths
- *(release)* Handle missing version tag in next_version task

### 📚 Documentation

- Add Claude Code skills and improve generator documentation
- Add definition skills and update module documentation
- Add comprehensive Claude Code skills for resources
- Add package and portal skills
- Add interaction skill for business logic actions
- *(skills)* Add new Claude Code skills and enhance existing ones

### 🎨 Styling

- Standardrb linting

### ⚙️ Miscellaneous Tasks

- Overhaul documentation structure and test infrastructure
- Move brakeman config to config/ and update ignore list
## [0.33.0] - 2026-01-12

### ◀️ Revert

- *(ui)* Remove semantic design token system
## [0.32.0] - 2026-01-12

### 🐛 Bug Fixes

- *(ui)* Move fontFamily to theme root level
## [0.31.0] - 2026-01-12

### 🚀 Features

- *(ui)* Add cross-tab color mode synchronization
- *(release)* Add npm package publishing support
- *(ui)* Add semantic design token system for theming

### 🐛 Bug Fixes

- *(core)* Preserve request format in redirects
- *(api)* Reset policy cache before rendering create response for api calls

### ⚙️ Miscellaneous Tasks

- *(release)* Build assets during prepare phase
## [0.28.0] - 2025-11-12

### 🚀 Features

- Add sgid support and improve association serialization in API

### 🐛 Bug Fixes

- Make controller_for inheritable and respect custom inflections
## [0.27.0] - 2025-11-05

### 🚀 Features

- Add field-level options support for input/display/column definitions

### 🐛 Bug Fixes

- Reload version constant in release:publish task

### 📚 Documentation

- Setup contribution guidelines using Conventional Commits
## [0.26.9] - 2025-09-25

### 🚀 Features

- Disable csrf protection if authorization header is set
## [0.26.8] - 2025-08-11

### 🐛 Bug Fixes

- Prevent SQLite adapter error when using non-SQLite databases (#42)
- Fix STI model routing logic in controller (#43)
## [0.26.6] - 2025-08-03

### 🚜 Refactor

- Enhance color mode selector and integrate into header layout (#41)
## [0.26.2] - 2025-07-22

### 🐛 Bug Fixes

- Handle redirect after interaction submission (#37)
- Enhance flatpickr to attach to modals correctly (#35)
## [0.23.2] - 2025-05-27

### 🚜 Refactor

- Update EasyMDE styles (#33)
## [0.23.1] - 2025-05-27

### 🐛 Bug Fixes

- Hide password visibility checkbox when not needed (#32)
## [0.21.1] - 2025-04-27

### 🚀 Features

- Preserve whitespace in hints to allow some formatting (#25)

### 🚜 Refactor

- Fix join condition for `has_one` and `has_many` associations (#23)
## [0.21.0] - 2025-04-01

### 🚀 Features

- Add cleaner cards for resources on the dashboard index page (#22)
## [0.20.4] - 2025-03-15

### 🐛 Bug Fixes

- Fix Tailwind CSS v4 upgrade issue for existing projects (#18)
## [0.19.13] - 2025-03-02

### 🚀 Features

- Add password visibility toggle to sign up and login forms (#17)
## [0.6.2] - 2024-02-21
