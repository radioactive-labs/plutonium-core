# require "plutonium"
# require "rails"
# require "active_model"
require "combustion"
Combustion.path = "test/internal"
Combustion.initialize! :all

require "minitest/autorun"
# # require "minitest/spec"

require "minitest/reporters"
Minitest::Reporters.use!

# # Configure Rails environment for testing
# ENV["RAILS_ENV"] = "test"
# # require File.expand_path("../config/environment", __dir__) if defined?(Rails)
