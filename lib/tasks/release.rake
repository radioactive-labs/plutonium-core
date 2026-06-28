# frozen_string_literal: true

# Release flow
# ------------
# Publishing happens from a laptop. CI does NOT push to any registry — it only
# cuts the GitHub Release (with notes + the built gem) when the tag lands.
#
#   1. rake release:prepare          # auto-computes next version via git-cliff
#      rake release:prepare[1.2.3]   # ...or pass one explicitly
#                                    # → bumps + regenerates changelog + builds assets,
#                                    #   STAGES them, and shows the diff. Nothing is committed.
#   2. git diff --cached             # review the staged changes
#   3. rake release:publish          # commits, publishes gem + npm, then tags + pushes
#                                    #   → CI cuts the Release from the tag
#
# To abort after prepare: git reset --hard (discards the staged changes).
# release:publish is idempotent and resumable: it skips a gem/npm already live
# and only tags if the tag is missing, so a partial failure can just be re-run.

require "json"

RELEASE_CLIFF_CONFIG = ".cliff.toml"
RELEASE_VERSION_FILE = "lib/plutonium/version.rb"
RELEASE_PACKAGE_JSON = "package.json"
RELEASE_NPM_PACKAGE = "@radioactive-labs/plutonium"

namespace :release do
  # --- helpers --------------------------------------------------------------

  def current_version
    File.read(RELEASE_VERSION_FILE)[/VERSION = "([\d.]+)"/, 1] ||
      abort("Could not read VERSION from #{RELEASE_VERSION_FILE}")
  end

  def git_cliff?
    system("which git-cliff > /dev/null 2>&1")
  end

  # Next version per conventional commits. git-cliff owns the semver math
  # (including the pre-1.0 rules configured under [bump] in .cliff.toml).
  def computed_next_version
    abort "git-cliff not found. Install with: brew install git-cliff" unless git_cliff?
    bumped = `git-cliff --config #{RELEASE_CLIFF_CONFIG} --bumped-version 2>/dev/null`.strip
    abort "git-cliff could not compute a version (no conventional commits since last tag?)" if bumped.empty?
    bumped.delete_prefix("v")
  end

  def gem_published?(version)
    out = `gem list --remote --exact --all plutonium 2>/dev/null`
    out.include?("#{version},") || out.include?("#{version})") || out.include?(" #{version} ")
  end

  def npm_published?(version)
    published = `npm view #{RELEASE_NPM_PACKAGE}@#{version} version 2>/dev/null`.strip
    published == version
  end

  # --- version --------------------------------------------------------------

  desc "Show the next version computed from conventional commits"
  task :version do
    puts "Current version: #{current_version}"
    puts "Next version:    #{computed_next_version}"
  end

  # --- prepare --------------------------------------------------------------

  desc "Stage a release (bump + changelog + assets) for review. Version optional; git-cliff computes it."
  task :prepare, [:version] do |_t, args|
    version = args[:version] || computed_next_version

    unless version.match?(/^\d+\.\d+\.\d+$/)
      abort "Error: version must be in format X.Y.Z (got #{version.inspect})"
    end

    unless `git status --porcelain`.strip.empty?
      abort "Error: working tree is dirty. Commit or stash first."
    end

    puts "Preparing release v#{version}..."

    # Bump version.rb
    content = File.read(RELEASE_VERSION_FILE)
    File.write(RELEASE_VERSION_FILE, content.gsub(/VERSION = "[\d.]+"/, %(VERSION = "#{version}")))
    puts "✓ #{RELEASE_VERSION_FILE}"

    # Bump package.json
    pkg = File.read(RELEASE_PACKAGE_JSON)
    File.write(RELEASE_PACKAGE_JSON, pkg.gsub(/"version":\s*"[\d.]+"/, %("version": "#{version}")))
    puts "✓ #{RELEASE_PACKAGE_JSON}"

    # Changelog — same config CI uses for release notes, so they agree.
    abort "git-cliff not found. Install with: brew install git-cliff" unless git_cliff?
    system("git-cliff", "--config", RELEASE_CLIFF_CONFIG, "--tag", "v#{version}", "-o", "CHANGELOG.md") ||
      abort("Changelog generation failed")
    puts "✓ CHANGELOG.md"

    # Rebuild committed frontend assets so the tagged tree ships current JS/CSS.
    Rake::Task["release:build_frontend"].invoke

    # Stage everything and show it — review happens BEFORE anything is committed.
    system("git", "add", "-A") || abort("git add failed")

    puts "\n✓ Staged release v#{version} (nothing committed yet)."
    puts "\nStaged changes:"
    system("git", "--no-pager", "diff", "--cached", "--stat")
    puts "\nNext:"
    puts "  git diff --cached     # review the full diff"
    puts "  rake release:publish  # commit, publish gem + npm, tag + push"
    puts "  git reset --hard      # abort and discard the staged changes"
  end

  desc "Build front-end assets"
  task :build_frontend do
    puts "Building front-end assets..."
    system("yarn build", in: File::NULL) || abort("Front-end build failed")
    puts "✓ Built front-end assets"
  end

  # --- publish (primary; idempotent + resumable) ----------------------------

  desc "Commit the prepared release, publish gem + npm, then tag + push (fires the Release workflow)"
  task publish: [:build_frontend] do
    version = current_version
    tag = "v#{version}"

    # Commit the changes prepare left staged for review. If the tree is already
    # clean (e.g. re-running after a partial failure), there's nothing to commit.
    if `git status --porcelain`.strip.empty?
      puts "• working tree clean — nothing to commit"
    else
      system("git", "add", "-A") || abort("git add failed")
      system("git", "commit", "-m", "chore(release): prepare for v#{version}") || abort("git commit failed")
      puts "✓ Committed release v#{version}"
    end

    # Gem (skip if this version is already on RubyGems)
    if gem_published?(version)
      puts "• gem plutonium #{version} already on RubyGems — skipping"
    else
      puts "Building + pushing gem..."
      system("gem build plutonium.gemspec") || abort("Gem build failed")
      gem_file = "plutonium-#{version}.gem"
      system("gem push #{gem_file}") || abort("Gem push failed")
      File.delete(gem_file) if File.exist?(gem_file)
      puts "✓ Published plutonium #{version} to RubyGems"
    end

    # npm (skip if this version is already published)
    if npm_published?(version)
      puts "• npm #{RELEASE_NPM_PACKAGE}@#{version} already published — skipping"
    else
      unless system("npm whoami > /dev/null 2>&1")
        puts "Not logged in to npm. Opening login..."
        system("npm login") || abort("npm login failed")
      end
      system("npm publish --access public") || abort("npm publish failed")
      puts "✓ Published #{RELEASE_NPM_PACKAGE} #{version} to npm"
    end

    # Tag + push last, so CI cuts the Release only once the packages are live.
    branch = `git branch --show-current`.strip
    if system("git rev-parse #{tag} >/dev/null 2>&1")
      puts "• tag #{tag} already exists — skipping tag"
    else
      system("git", "tag", tag) || abort("git tag failed")
    end
    system("git", "push", "origin", branch) || abort("git push branch failed")
    system("git", "push", "origin", tag) || abort("git push tag failed")

    puts "\n✓ Released #{tag}. GitHub Actions will cut the Release from the tag."
    puts "  Watch: https://github.com/radioactive-labs/plutonium-core/actions"
  end
end

# Neutralize the dangerous bare `rake release` that bundler/gem_tasks defines
# (it would tag + gem push directly). Point people at the real flow instead.
if Rake::Task.task_defined?("release")
  Rake::Task["release"].clear
  task :release do
    warn "Use `rake release:prepare` then `rake release:publish`. See lib/tasks/release.rake."
  end
end
