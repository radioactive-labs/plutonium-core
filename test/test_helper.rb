# frozen_string_literal: true

# Set the Rails env to test
ENV["RAILS_ENV"] ||= "test"

# Load the dummy Rails application
require_relative "dummy/config/environment"

# Ensure database exists and run migrations
# Ensure migration paths include the absolute paths from Rails config
ActiveRecord::Migrator.migrations_paths = Rails.application.config.paths["db/migrate"].to_a
# Drop any stale DB from a previously-killed run so leftover tables don't collide with migrations.
ActiveRecord::Tasks::DatabaseTasks.drop_current
ActiveRecord::Tasks::DatabaseTasks.create_current
ActiveRecord::Tasks::DatabaseTasks.migrate

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use!

# Load test support files
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }
