# frozen_string_literal: true

namespace :release do
  desc "Display next version based on conventional commits"
  task :next_version do
    current_version = Plutonium::VERSION
    puts "Current version: #{current_version}"

    # Find the tag to compare against
    version_tag = "v#{current_version}"
    tag_exists = system("git rev-parse #{version_tag} >/dev/null 2>&1")

    unless tag_exists
      # Fall back to most recent tag
      version_tag = `git describe --tags --abbrev=0 2>/dev/null`.strip
      if version_tag.empty?
        puts "No tags found, comparing against initial commit"
        version_tag = `git rev-list --max-parents=0 HEAD`.strip
      else
        puts "Tag v#{current_version} not found, comparing against #{version_tag}"
      end
    end

    # Check for breaking changes, features, or fixes since last tag
    breaking = `git log #{version_tag}..HEAD --oneline | grep -i "BREAKING CHANGE"`.strip
    features = `git log #{version_tag}..HEAD --oneline | grep "^[a-f0-9]* feat"`.strip
    fixes = `git log #{version_tag}..HEAD --oneline | grep "^[a-f0-9]* fix"`.strip

    major, minor, patch = current_version.split(".").map(&:to_i)

    if !breaking.empty?
      next_version = "#{major + 1}.0.0"
      puts "Next version (breaking changes): #{next_version}"
    elsif !features.empty?
      next_version = "#{major}.#{minor + 1}.0"
      puts "Next version (new features): #{next_version}"
    elsif !fixes.empty?
      next_version = "#{major}.#{minor}.#{patch + 1}"
      puts "Next version (bug fixes): #{next_version}"
    else
      puts "No changes detected"
    end
  end

  desc "Prepare a new release"
  task :prepare, [:version] do |_t, args|
    version = args[:version]

    unless version
      puts "Usage: rake release:prepare[VERSION]"
      puts "Example: rake release:prepare[0.27.0]"
      exit 1
    end

    # Validate version format
    unless version.match?(/^\d+\.\d+\.\d+$/)
      puts "Error: Version must be in format X.Y.Z"
      exit 1
    end

    # Update version.rb
    version_file = "lib/plutonium/version.rb"
    content = File.read(version_file)
    updated_content = content.gsub(/VERSION = "[\d.]+"/, %(VERSION = "#{version}"))
    File.write(version_file, updated_content)
    puts "✓ Updated #{version_file}"

    # Update package.json version
    package_json_file = "package.json"
    if File.exist?(package_json_file)
      package_content = File.read(package_json_file)
      updated_package = package_content.gsub(/"version":\s*"[\d.]+"/, %("version": "#{version}"))
      File.write(package_json_file, updated_package)
      puts "✓ Updated #{package_json_file}"
    end

    # Generate changelog using git-cliff
    if system("which git-cliff > /dev/null 2>&1")
      system("git-cliff --tag v#{version} -o CHANGELOG.md")
      puts "✓ Generated CHANGELOG.md"
    else
      puts "⚠ git-cliff not found. Install with: brew install git-cliff"
      puts "  Skipping changelog generation"
    end

    # Build front-end assets
    Rake::Task["release:build_frontend"].invoke

    puts "\nNext steps:"
    puts "1. Review the changes:"
    puts "   git diff"
    puts "2. Commit the version bump:"
    puts "   git add -A"
    puts "   git commit -m 'chore(release): prepare for v#{version}'"
    puts "3. Create and push the tag:"
    puts "   git tag v#{version}"
    puts "   git push origin main --tags"
    puts "4. Build and release:"
    puts "   rake release:publish"
  end

  desc "Build front-end assets"
  task :build_frontend do
    puts "Building front-end assets..."
    system("npm run build") || abort("Front-end build failed")
    puts "✓ Built front-end assets"
  end

  desc "Publish the gem to RubyGems"
  task :publish_gem do
    # Reload version constant in case it was updated
    load "lib/plutonium/version.rb"
    version = Plutonium::VERSION

    # Build the gem
    puts "Building gem..."
    system("gem build plutonium.gemspec") || abort("Gem build failed")

    # Push to RubyGems
    puts "Publishing to RubyGems..."
    gem_file = "plutonium-#{version}.gem"
    system("gem push #{gem_file}") || abort("Gem push failed")

    puts "✓ Published plutonium #{version} to RubyGems"

    # Clean up
    File.delete(gem_file) if File.exist?(gem_file)
  end

  desc "Publish the npm package"
  task :publish_npm do
    puts "Publishing npm package..."

    # Check if user is logged in to npm
    unless system("npm whoami > /dev/null 2>&1")
      puts "⚠ You are not logged in to npm. Please run: npm login"
      abort("npm authentication required")
    end

    # Publish to npm
    system("npm publish --access public") || abort("npm publish failed")

    # Get version from package.json
    require "json"
    package_json = JSON.parse(File.read("package.json"))
    version = package_json["version"]

    puts "✓ Published @radioactive-labs/plutonium #{version} to npm"
  end

  desc "Publish both gem and npm package"
  task publish: [:build_frontend, :publish_gem, :publish_npm]

  desc "Full release workflow"
  task :full, [:version] do |_t, args|
    version = args[:version]

    unless version
      puts "Usage: rake release:full[VERSION]"
      exit 1
    end

    puts "Starting release workflow for v#{version}..."

    # Check for uncommitted changes
    unless `git status --porcelain`.strip.empty?
      puts "Error: You have uncommitted changes. Please commit or stash them first."
      exit 1
    end

    # Check we're on main branch
    current_branch = `git branch --show-current`.strip
    unless current_branch == "main" || current_branch == "master"
      puts "Warning: You're not on main/master branch (current: #{current_branch})"
      print "Continue anyway? [y/N] "
      exit 1 unless $stdin.gets.strip.downcase == "y"
    end

    # Prepare release
    Rake::Task["release:prepare"].invoke(version)

    # Confirm before proceeding
    puts "\nReady to commit, tag, and publish?"
    print "Continue? [y/N] "
    exit 0 unless $stdin.gets.strip.downcase == "y"

    # Commit
    system("git add -A")
    system("git commit -m 'chore(release): prepare for v#{version}'")

    # Push commit (without tags yet)
    system("git push origin #{current_branch}")

    # Build and publish (do this BEFORE tagging)
    puts "\nBuilding and publishing gem and npm package..."
    Rake::Task["release:publish"].invoke

    # Only tag and push tag if publish succeeded
    puts "\nCreating and pushing tag..."
    system("git tag v#{version}")
    system("git push origin v#{version}")

    puts "\n✓ Release complete!"
    puts "GitHub Actions will create the release shortly."
  end
end

desc "Release tasks"
task release: ["release:next_version"]
