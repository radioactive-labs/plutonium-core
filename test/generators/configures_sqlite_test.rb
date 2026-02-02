# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "generators/pu/lib/plutonium_generators"

class ConfiguresSqliteTest < ActiveSupport::TestCase
  DatabaseYAML = PlutoniumGenerators::Concerns::ConfiguresSqlite::DatabaseYAML

  SAMPLE_DATABASE_YML = <<~YAML
    default: &default
      adapter: sqlite3
      pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      timeout: 5000

    development:
      <<: *default
      database: storage/development.sqlite3

    test:
      <<: *default
      database: storage/test.sqlite3

    production:
      <<: *default
      database: storage/production.sqlite3
  YAML

  def setup
    @temp_file = Tempfile.new(["database", ".yml"])
    @temp_file.write(SAMPLE_DATABASE_YML)
    @temp_file.rewind
  end

  def teardown
    @temp_file.close
    @temp_file.unlink
  end

  test "DatabaseYAML parses valid database.yml" do
    db_yaml = DatabaseYAML.new(path: @temp_file.path)
    assert db_yaml.content.include?("default: &default")
  end

  test "new_database generates correct database definition" do
    db_yaml = DatabaseYAML.new(path: @temp_file.path)
    result = db_yaml.new_database("queue")

    assert_match(/queue: &queue/, result)
    assert_match(/<<: \*default/, result)
    assert_match(/migrations_paths: db\/queue_migrate/, result)
    assert_match(/storage\/<%= Rails.env %>-queue.sqlite3/, result)
  end

  test "database_def_regex matches database definitions" do
    db_yaml = DatabaseYAML.new(path: @temp_file.path)
    regex = db_yaml.database_def_regex("default")

    assert_match(regex, db_yaml.content)
  end

  test "add_database returns environment entries" do
    db_yaml = DatabaseYAML.new(path: @temp_file.path)
    results = db_yaml.add_database("queue")

    assert results.is_a?(Array)
    # Should have entries for development, test, production
    environments = results.map(&:first)
    assert_includes environments, "development"
    assert_includes environments, "test"
    assert_includes environments, "production"
  end
end
