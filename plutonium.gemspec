require_relative "lib/plutonium/version"

Gem::Specification.new do |spec|
  spec.name = "plutonium"
  spec.version = Plutonium::VERSION
  spec.authors = ["Stefan Froelich"]
  spec.email = ["sfroelich01@gmail.com"]

  spec.summary = "Build production-ready Rails apps in minutes, not days"
  spec.description = "Plutonium is a Rapid Application Development toolkit for Rails. " \
                     "Convention-driven and fully customizable, it adds application-level concepts like resources, policies, " \
                     "definitions, and portals that make building complex apps faster. Built for the AI era with Claude Code skills."
  spec.homepage = "https://radioactive-labs.github.io/plutonium-core/"
  spec.license = "MIT"
  # Ruby 3.2 is DEPRECATED and will be dropped in the next release — see the
  # post_install_message. Held here for one more release so 3.2 users can
  # receive the fixes in this one before support ends; raising it in the same
  # release that ships them would strand those users on the old version.
  spec.required_ruby_version = ">= 3.2.2"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  # Require multi-factor auth for privileged RubyGems actions (push, yank,
  # owner changes). `gem push` will prompt for an OTP at release time.
  spec.metadata["rubygems_mfa_required"] = "true"

  # Prints on EVERY install: only notices still actionable for someone
  # installing THIS version.
  spec.post_install_message = <<~MSG
    ⚠️  Ruby 3.2 support ends in the NEXT release

    This is the last Plutonium release that installs on Ruby 3.2.

    Why: pagy patches CVE-2026-54659 (a path-traversal in
    `Pagy::I18n.locale=`) only in >= 43.5.6, and pagy dropped Ruby 3.2 in
    43.5.0. No pagy version is both patched and installable on 3.2, so
    continuing to support it means shipping a known-vulnerable dependency.

    Ruby 3.2 reached end-of-life in March 2026.

    Action: upgrade to Ruby 3.3 or newer before your next Plutonium bump.
    If you stay on 3.2, `bundle update plutonium` will hold you here.
  MSG

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/radioactive-labs/plutonium-core"
  # spec.metadata["changelog_uri"] = "https://google.com"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "zeitwerk"
  spec.add_dependency "rails", ">= 7.2.3.1"
  spec.add_dependency "csv" # CSV export; no longer a default gem on Ruby 3.4+
  spec.add_dependency "listen", "~> 3.8"
  # NOT pinned to >= 43.5.6 (which patches CVE-2026-54659) yet: that version
  # requires Ruby >= 3.3, so pinning it here would silently drop Ruby 3.2 a
  # release early. `~> 43.0` already resolves to a patched 43.6.x on any fresh
  # install under Ruby 3.3+, so the exposure is limited to apps holding an old
  # pagy in their lockfile. Pin it in the release that drops 3.2.
  spec.add_dependency "pagy", "~> 43.0"
  spec.add_dependency "rabl", "~> 0.17.0" # TODO: what to do with RABL
  spec.add_dependency "semantic_range", "~> 3.0"
  spec.add_dependency "tty-prompt", "~> 0.23.1"
  spec.add_dependency "action_policy", "~> 0.7.0"
  spec.add_dependency "phlex", "~> 2.0"
  spec.add_dependency "phlex-rails"
  spec.add_dependency "phlex-tabler_icons"
  spec.add_dependency "phlexi-field", ">= 0.2.0"
  spec.add_dependency "phlexi-form", ">= 0.14.3"
  spec.add_dependency "phlexi-table", ">= 0.2.0"
  spec.add_dependency "phlexi-display", ">= 0.2.0"
  spec.add_dependency "phlexi-menu", ">= 0.4.1"
  spec.add_dependency "tailwind_merge"
  spec.add_dependency "phlex-slotable", ">= 1.0.0"
  spec.add_dependency "redcarpet"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "brakeman"
  spec.add_development_dependency "bundle-audit"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "combustion"
  spec.add_development_dependency "capybara"
  spec.add_development_dependency "selenium-webdriver"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
