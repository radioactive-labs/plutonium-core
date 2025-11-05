# Release Workflow Quick Reference

## Prerequisites

```bash
# Install git-cliff (one-time setup)
brew install git-cliff  # macOS
# or
cargo install git-cliff  # via Rust/Cargo
```

## Quick Release

```bash
# One-command release
rake release:full[0.27.0]
```

This will:
1. ✓ Check for uncommitted changes
2. ✓ Update version in `lib/plutonium/version.rb`
3. ✓ Generate/update CHANGELOG.md
4. ✓ Create commit: `chore(release): prepare for v0.27.0`
5. ✓ Create git tag: `v0.27.0`
6. ✓ Push to GitHub
7. ✓ Trigger GitHub Action to publish to RubyGems

## Step-by-Step Release

### 1. Check Next Version

```bash
rake release:next_version
```

This analyzes commits since last tag and suggests version bump.

### 2. Prepare Release

```bash
rake release:prepare[0.27.0]
```

Updates version file and generates changelog.

### 3. Review Changes

```bash
git diff
cat CHANGELOG.md
```

### 4. Commit & Tag

```bash
git add -A
git commit -m "chore(release): prepare for v0.27.0"
git tag v0.27.0
```

### 5. Push

```bash
git push origin main --tags
```

### 6. Publish (Automated)

GitHub Actions will automatically:
- Build the gem
- Publish to RubyGems
- Create GitHub release with notes

## Manual Changelog Generation

```bash
# Generate changelog for specific tag
git-cliff --tag v0.27.0 -o CHANGELOG.md

# Generate changelog between tags
git-cliff v0.26.0..v0.27.0

# Preview unreleased changes
git-cliff --unreleased
```

## Conventional Commit Cheat Sheet

```bash
# New feature (minor bump: 0.26.x → 0.27.0)
git commit -m "feat: add new feature"

# Bug fix (patch bump: 0.26.11 → 0.26.12)
git commit -m "fix: resolve bug"

# Breaking change (major bump: 0.x.x → 1.0.0)
git commit -m "feat!: breaking change"

# With scope
git commit -m "feat(ui): add component"
git commit -m "fix(forms): fix validation"

# Documentation (no version bump)
git commit -m "docs: update guide"

# Chore (no version bump)
git commit -m "chore: update dependencies"
```

## Troubleshooting

### "git-cliff: command not found"

Install git-cliff:
```bash
brew install git-cliff
```

### "Gem push failed"

Ensure RubyGems API key is configured:
```bash
gem signin
```

Or add to `~/.gem/credentials`:
```yaml
---
:rubygems_api_key: YOUR_API_KEY
```

### GitHub Action not running

1. Check that tag was pushed: `git push origin main --tags`
2. Verify RUBYGEMS_API_KEY secret is set in GitHub repo settings
3. Check Actions tab for workflow runs

## Version Bump Decision Tree

```
Has BREAKING CHANGE or `!`?
├─ Yes → MAJOR (1.0.0, 2.0.0, etc)
└─ No
   └─ Has `feat:`?
      ├─ Yes → MINOR (0.1.0, 0.2.0, etc)
      └─ No
         └─ Has `fix:`?
            ├─ Yes → PATCH (0.0.1, 0.0.2, etc)
            └─ No → No version bump
```

## Emergency Patch

For urgent fixes without full release prep:

```bash
# 1. Make fix with conventional commit
git commit -m "fix: critical security issue"

# 2. Quick release
rake release:full[0.26.12]
```
