require_relative "lib/plutonium/version"

Gem::Specification.new do |spec|
  spec.name = "plutonium"
  spec.version = Plutonium::VERSION
  spec.authors = ["Stefan Froelich"]
  spec.email = ["sfroelich01@gmail.com"]

  spec.summary = "Write a short summary, because RubyGems requires one."
  spec.description = "Write a longer description or delete this line."
  spec.homepage = "https://google.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.2"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://google.com"
  spec.metadata["changelog_uri"] = "https://google.com"

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

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "activesupport", "~> 7.1.2"
  spec.add_dependency "railties", "~> 7.1.2"
  spec.add_dependency "actionpack", "~> 7.1.2"
  spec.add_dependency "pagy", "~> 6.2.0"
  spec.add_dependency "pundit" # , "~> 6.2.0"
  # spec.add_dependency "rails", ">= 7.1.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
