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
