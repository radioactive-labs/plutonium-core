# frozen_string_literal: true

require "test_helper"
require "generators/pu/lib/plutonium_generators"

class ConfiguresSqliteTest < ActiveSupport::TestCase
  include DatabaseYmlHelper

  DatabaseYAML = PlutoniumGenerators::Concerns::ConfiguresSqlite::DatabaseYAML
  ConfiguresDatabase = PlutoniumGenerators::Concerns::ConfiguresDatabase

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
    refute_match(/adapter:/, result)
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

  test "a SQLite default is inherited and re-running changes nothing" do
    with_database_yml(SAMPLE_DATABASE_YML) do |dir|
      add_secondary_database(dir, "queue")
      once = read_database_yml(dir)
      add_secondary_database(dir, "queue")

      assert_equal 5000, load_database_yml(dir)["development"]["queue"]["timeout"]
      assert_equal once, read_database_yml(dir)
    end
  end

  test "databases added under a PostgreSQL default are PostgreSQL databases" do
    with_database_yml(postgres_database_yml) do |dir|
      %w[queue cache].each { |name| add_secondary_database(dir, name) }
      once = read_database_yml(dir)
      config = load_database_yml(dir)

      refute_match(/sqlite/i, once)
      %w[development test production].each do |env|
        primary = config[env]["primary"]
        %w[queue cache].each do |name|
          db = config[env][name]
          assert_equal "#{primary["database"]}_#{name}", db["database"], "#{env}.#{name}"
          assert_equal "db/#{name}_migrate", db["migrations_paths"]
          # same connection settings as the primary
          assert_equal primary.except("database"), db.except("database", "migrations_paths"), "#{env}.#{name}"
        end
      end

      add_secondary_database(dir, "queue")
      assert_equal once, read_database_yml(dir)
    end
  end

  test "schema_dump is carried onto a PostgreSQL database entry" do
    with_database_yml(postgres_database_yml) do |dir|
      add_secondary_database(dir, "rails_pulse", migrations_paths: "db/rails_pulse_migrate", schema_dump: false)

      db = load_database_yml(dir)["development"]["rails_pulse"]
      assert_equal "db/rails_pulse_migrate", db["migrations_paths"]
      assert_equal false, db["schema_dump"]
    end
  end

  STOCK_RAILS_POSTGRES_YML = <<~YAML
    default: &default
      adapter: postgresql
      encoding: unicode

    development:
      <<: *default
      database: app_development

    production:
      primary: &primary_production
        <<: *default
        database: app_production
        username: app
      queue:
        <<: *primary_production
        database: app_production_queue
        migrations_paths: db/queue_migrate
  YAML

  test "a stock Rails PostgreSQL database.yml keeps the production databases it already has" do
    with_database_yml(STOCK_RAILS_POSTGRES_YML) do |dir|
      add_secondary_database(dir, "queue")

      assert_equal "app_development_queue", load_database_yml(dir)["development"]["queue"]["database"]
      assert_equal STOCK_RAILS_POSTGRES_YML[/^production:.*/m], read_database_yml(dir)[/^production:.*/m]
    end
  end

  test "an environment it cannot edit is reported, not silently skipped" do
    # comments between keys: the parsed block no longer matches the file text
    commented = postgres_database_yml.sub("  <<: [*default, *local]\n", "  <<: [*default, *local]\n  # between keys\n")
    with_database_yml(commented) do |dir|
      out = add_secondary_database(dir, "queue")

      assert_match(/error\s+queue -> development: could not edit database.yml/, out)
      assert_equal commented[/^development:.*?^test:/m], read_database_yml(dir)[/^development:.*?^test:/m]
      assert_match(/add_db\s+queue -> test/, out)
    end
  end

  test "a primary without a literal database name is reported and left alone" do
    yml = STOCK_RAILS_POSTGRES_YML.sub("  database: app_development\n", "  url: <%= ENV[\"DATABASE_URL\"] %>\n")
    with_database_yml(yml) do |dir|
      out = add_secondary_database(dir, "queue")

      assert_match(/skip\s+queue -> development: no literal `database:`/, out)
      assert_equal yml[/^development:.*?^production:/m], read_database_yml(dir)[/^development:.*?^production:/m]
    end
  end

  test "an environment with neither a primary nor its own database is left alone" do
    yml = "default: &default\n  adapter: postgresql\n\ndevelopment:\n  queue:\n    <<: *default\n    database: q\n"
    with_database_yml(yml) do |dir|
      add_secondary_database(dir, "cache")

      assert_equal yml, read_database_yml(dir)
    end
  end

  test "the editor is chosen by the adapter of the default block" do
    sqlite = ConfiguresDatabase::DatabaseYAML.for(@temp_file.path)
    assert_instance_of DatabaseYAML, sqlite
    assert_equal "sqlite3", sqlite.default_adapter

    with_database_yml(postgres_database_yml) do |dir|
      yaml = ConfiguresDatabase::DatabaseYAML.for(File.join(dir, "config/database.yml"))

      assert_instance_of ConfiguresDatabase::DatabaseYAML, yaml
      assert_equal "postgresql", yaml.default_adapter
      refute yaml.sqlite?
    end
  end
end
