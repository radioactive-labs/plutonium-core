# Uncomment and update these requires as needed
# require "plutonium"
# require "rails"
# require "active_model"

require "combustion"
Combustion.path = "test/internal"
Combustion.initialize! :all

require "minitest/autorun"
# Uncomment if you decide to use spec-style syntax
# require "minitest/spec"

require "minitest/reporters"
Minitest::Reporters.use!

# Uncomment and adjust Rails environment setup if needed
# ENV["RAILS_ENV"] = "test"
# require File.expand_path("../config/environment", __dir__) if defined?(Rails)
