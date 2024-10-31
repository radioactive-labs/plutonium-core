require_relative "lib/plutonium/version"

Gem::Specification.new do |spec|
  spec.name = "plutonium"
  spec.version = Plutonium::VERSION
  spec.authors = ["Stefan Froelich"]
  spec.email = ["sfroelich01@gmail.com"]

  spec.summary = "The Ultimate Rapid Application Development Toolkit (RADKit) for Rails"
  spec.description = "Plutonium extends Rails' capabilities with a powerful, generator-driven toolkit designed to supercharge your development process. " \
                     "It transforms the way you build applications with Rails, optimizing for rapid application development."
  spec.homepage = "https://radioactive-labs.github.io/plutonium-core/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.2"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

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
  spec.add_dependency "rails", ">= 7.1", "< 8.0"
  spec.add_dependency "listen", "~> 3.8"
  spec.add_dependency "pagy", "~> 9.0"
  spec.add_dependency "simple_form", "~> 5.3"
  spec.add_dependency "view_component", "~> 3"
  spec.add_dependency "dry-initializer", "~> 3.1"
  spec.add_dependency "rabl", "~> 0.16.1" # TODO: what to do with RABL
  spec.add_dependency "semantic_range", "~> 3.0"
  spec.add_dependency "tty-prompt", "~> 0.23.1"
  spec.add_dependency "action_policy", "~> 0.7.0"
  spec.add_dependency "phlex", "~> 1.11"
  spec.add_dependency "phlex-rails"
  spec.add_dependency "phlex-tabler_icons"
  spec.add_dependency "phlexi-form"
  spec.add_dependency "phlexi-table"
  spec.add_dependency "phlexi-display"
  spec.add_dependency "tailwind_merge"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "brakeman"
  spec.add_development_dependency "bundle-audit"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "combustion"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
