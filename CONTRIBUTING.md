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

## Version Bumping Rules

Following semantic versioning:

- **MAJOR** (X.0.0): Breaking changes
- **MINOR** (0.X.0): New features (backwards compatible)
- **PATCH** (0.0.X): Bug fixes (backwards compatible)

The automation determines the version bump based on commits since the last tag:
- Any commit with `BREAKING CHANGE:` or `!` after type → MAJOR
- Any `feat:` commits → MINOR
- Any `fix:` commits → PATCH

## Development Setup

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Install git-cliff for changelog generation (optional)
brew install git-cliff  # macOS
# or
cargo install git-cliff  # via Rust
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes with conventional commits
4. Run tests: `bundle exec rspec`
5. Push and create a pull request
6. The PR title should also follow conventional commit format

## Questions?

Open an issue or discussion on GitHub!
