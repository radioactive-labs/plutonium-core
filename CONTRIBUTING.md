# Contributing to Plutonium

## Commit Message Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/) for automated changelog generation and versioning.

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- **feat**: A new feature (triggers MINOR version bump)
- **fix**: A bug fix (triggers PATCH version bump)
- **docs**: Documentation only changes
- **style**: Changes that don't affect code meaning (formatting, etc)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Performance improvement
- **test**: Adding or updating tests
- **chore**: Maintenance tasks (dependencies, tooling, etc)

### Breaking Changes

Add `BREAKING CHANGE:` in the footer or `!` after type to trigger a MAJOR version bump:

```
feat!: remove deprecated API

BREAKING CHANGE: The old API has been removed. Use new API instead.
```

### Examples

```bash
# Feature (bumps 0.26.11 -> 0.27.0)
git commit -m "feat: add field-level options support for input definitions"

# Bug fix (bumps 0.26.11 -> 0.26.12)
git commit -m "fix: resolve inheritance issue with controller_for"

# Breaking change (bumps 0.26.11 -> 1.0.0)
git commit -m "feat!: redesign definition DSL

BREAKING CHANGE: The definition DSL has been completely redesigned.
See migration guide for details."

# With scope
git commit -m "feat(ui): add new table component"
git commit -m "fix(forms): correct hint display on validation errors"

# Documentation
git commit -m "docs: update definition structure guide"
```

## Release Process

### Option 1: Automated (Recommended)

```bash
# See what the next version should be
rake release:next_version

# Prepare a new release (updates version, generates changelog)
rake release:prepare[0.27.0]

# Review changes
git diff

# Full automated release (prepare, commit, tag, push, publish)
rake release:full[0.27.0]
```

### Option 2: Manual

```bash
# 1. Update version in lib/plutonium/version.rb
# 2. Generate changelog
git-cliff --tag v0.27.0 -o CHANGELOG.md

# 3. Commit and tag
git add -A
git commit -m "chore(release): prepare for v0.27.0"
git tag v0.27.0
git push origin main --tags

# 4. GitHub Actions will automatically publish to RubyGems
```

## Development Setup

### Prerequisites

- Ruby 3.2+
- Node.js 18+
- PostgreSQL (for tests)

### Install Dependencies

```bash
bundle install
yarn install
```

### Environment

Set this when working on Plutonium:

```bash
export PLUTONIUM_DEV=1
```

This uses local assets and enables hot reloading.

### Building Assets

Frontend source is in `src/`. When making JS or CSS changes:

```bash
# Watch mode - keeps rebuilding as you edit
yarn dev

# Production build - run before committing
yarn build
```

### Running Tests

Tests run via [Appraisal](https://github.com/thoughtbot/appraisal) against multiple Rails versions:

```bash
# Full test suite (all Rails versions)
bundle exec appraisal rake test

# Specific Rails version
bundle exec appraisal rails-8.1 rake test

# Specific test file
bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/policy_test.rb
```

Available appraisals: `rails-7`, `rails-8.0`, `rails-8.1`

### Testing Generators

Use the dummy app:

```bash
cd test/dummy
rails g pu:res:scaffold TestModel name:string --dest=main_app
rails db:migrate
bin/dev
```

### Documentation

```bash
yarn docs:dev      # Preview at localhost:5173
yarn docs:build    # Check for errors
```

### Changelog Generation (optional)

```bash
brew install git-cliff  # macOS
# or
cargo install git-cliff  # via Rust
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes with conventional commits
4. Run tests: `bundle exec appraisal rake test`
5. Build assets: `yarn build`
6. Push and create a pull request

## Questions?

Open an issue or discussion on GitHub!
