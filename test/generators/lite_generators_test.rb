# frozen_string_literal: true

require "test_helper"
require "rails/generators"

class LiteGeneratorsTest < ActiveSupport::TestCase
  def self.load_generators
    require "generators/pu/lite/setup/setup_generator"
    require "generators/pu/lite/solid_queue/solid_queue_generator"
    require "generators/pu/lite/solid_cache/solid_cache_generator"
    require "generators/pu/lite/solid_cable/solid_cable_generator"
    require "generators/pu/lite/solid_errors/solid_errors_generator"
    require "generators/pu/lite/litestream/litestream_generator"
    require "generators/pu/lite/rails_pulse/rails_pulse_generator"
    require "generators/pu/lite/tune/tune_generator"
    require "generators/pu/lite/maintenance/maintenance_generator"
  end

  load_generators
  # Test Setup Generator
  test "setup generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SetupGenerator)
    assert Pu::Lite::SetupGenerator < Rails::Generators::Base
  end

  test "setup generator includes PlutoniumGenerators::Generator" do
    assert Pu::Lite::SetupGenerator.include?(PlutoniumGenerators::Generator)
  end

  # Test Solid Queue Generator
  test "solid_queue generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SolidQueueGenerator)
    assert Pu::Lite::SolidQueueGenerator < Rails::Generators::Base
  end

  test "solid_queue generator has database option with default 'queue'" do
    options = Pu::Lite::SolidQueueGenerator.class_options
    assert options.key?(:database)
    assert_equal "queue", options[:database].default
  end

  test "solid_queue generator has route option with default '/manage/jobs'" do
    options = Pu::Lite::SolidQueueGenerator.class_options
    assert options.key?(:route)
    assert_equal "/manage/jobs", options[:route].default
  end

  test "solid_queue generator has skip_mission_control option" do
    options = Pu::Lite::SolidQueueGenerator.class_options
    assert options.key?(:skip_mission_control)
    assert_equal false, options[:skip_mission_control].default
  end

  # Test Solid Cache Generator
  test "solid_cache generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SolidCacheGenerator)
  end

  test "solid_cache generator has database option with default 'cache'" do
    options = Pu::Lite::SolidCacheGenerator.class_options
    assert options.key?(:database)
    assert_equal "cache", options[:database].default
  end

  test "solid_cache generator has dev_cache option" do
    options = Pu::Lite::SolidCacheGenerator.class_options
    assert options.key?(:dev_cache)
    assert_equal true, options[:dev_cache].default
  end

  # Test Solid Cable Generator
  test "solid_cable generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SolidCableGenerator)
  end

  test "solid_cable generator has database option with default 'cable'" do
    options = Pu::Lite::SolidCableGenerator.class_options
    assert options.key?(:database)
    assert_equal "cable", options[:database].default
  end

  # Test Solid Errors Generator
  test "solid_errors generator exists and has correct namespace" do
    assert defined?(Pu::Lite::SolidErrorsGenerator)
  end

  test "solid_errors generator has database option with default 'errors'" do
    options = Pu::Lite::SolidErrorsGenerator.class_options
    assert options.key?(:database)
    assert_equal "errors", options[:database].default
  end

  test "solid_errors generator has route option with default '/manage/errors'" do
    options = Pu::Lite::SolidErrorsGenerator.class_options
    assert options.key?(:route)
    assert_equal "/manage/errors", options[:route].default
  end

  # Test Litestream Generator
  test "litestream generator exists and has correct namespace" do
    assert defined?(Pu::Lite::LitestreamGenerator)
  end

  test "litestream generator has route option with default '/manage/litestream'" do
    options = Pu::Lite::LitestreamGenerator.class_options
    assert options.key?(:route)
    assert_equal "/manage/litestream", options[:route].default
  end

  test "litestream generator has credentials option defaulting to true" do
    options = Pu::Lite::LitestreamGenerator.class_options
    assert options.key?(:credentials)
    assert_equal true, options[:credentials].default
  end

  # Test generators include appropriate concerns
  test "solid_queue generator includes ConfiguresSqlite and MountsEngines concerns" do
    assert Pu::Lite::SolidQueueGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
    assert Pu::Lite::SolidQueueGenerator.include?(PlutoniumGenerators::Concerns::MountsEngines)
  end

  test "solid_cache generator includes ConfiguresSqlite concern" do
    assert Pu::Lite::SolidCacheGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
  end

  test "solid_cable generator includes ConfiguresSqlite concern" do
    assert Pu::Lite::SolidCableGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
  end

  test "solid_errors generator includes ConfiguresSqlite and MountsEngines concerns" do
    assert Pu::Lite::SolidErrorsGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresSqlite)
    assert Pu::Lite::SolidErrorsGenerator.include?(PlutoniumGenerators::Concerns::MountsEngines)
  end

  test "litestream generator includes MountsEngines concern" do
    assert Pu::Lite::LitestreamGenerator.include?(PlutoniumGenerators::Concerns::MountsEngines)
  end

  # Test Tune Generator
  test "tune generator exists and has correct namespace" do
    assert defined?(Pu::Lite::TuneGenerator)
    assert Pu::Lite::TuneGenerator < Rails::Generators::Base
  end

  test "tune generator includes PlutoniumGenerators::Generator" do
    assert Pu::Lite::TuneGenerator.include?(PlutoniumGenerators::Generator)
  end

  test "tune pragma block on rails 8.1 contains the four deltas and no baseline" do
    gen = Pu::Lite::TuneGenerator.new([], {}, {})
    block = gen.send(:pragma_block, ::Gem::Version.new("8.1.0"))

    %w[cache_size temp_store mmap_size wal_autocheckpoint].each do |key|
      assert_match(/#{key}:/, block)
    end
    refute_match(/journal_mode:/, block)
    refute_match(/busy_timeout/, block)
    assert_match(/pragmas:/, block)
  end

  test "tune pragma block on rails < 8.1 also contains baseline pragmas" do
    gen = Pu::Lite::TuneGenerator.new([], {}, {})
    block = gen.send(:pragma_block, ::Gem::Version.new("8.0.0"))

    %w[journal_mode synchronous foreign_keys journal_size_limit].each do |key|
      assert_match(/#{key}:/, block)
    end
  end

  FRESH_DB_YML = <<~YAML
    default: &default
      adapter: sqlite3
      pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      timeout: 5000

    development:
      <<: *default
      database: storage/development.sqlite3

    production:
      <<: *default
      database: storage/production.sqlite3
  YAML

  EXISTING_PRAGMAS_DB_YML = <<~YAML
    default: &default
      adapter: sqlite3
      pool: 5
      timeout: 5000
      pragmas:
        journal_mode: WAL

    development:
      <<: *default
      database: storage/development.sqlite3
  YAML

  # pragmas: nested under production.primary, none under default — the edge case
  PRAGMAS_ELSEWHERE_DB_YML = <<~YAML
    default: &default
      adapter: sqlite3
      pool: 5
      timeout: 5000

    production:
      primary:
        <<: *default
        database: storage/production.sqlite3
        pragmas:
          journal_mode: WAL
  YAML

  def render_and_load(yaml)
    require "erb"
    require "yaml"
    YAML.safe_load(ERB.new(yaml).result, aliases: true)
  end

  test "apply_pragmas inserts a pragmas block under default on a fresh file" do
    gen = Pu::Lite::TuneGenerator.new([], {}, {})
    result = gen.send(:apply_pragmas, FRESH_DB_YML, ::Gem::Version.new("8.1.0"))

    parsed = render_and_load(result)
    assert_equal(-64000, parsed["default"]["pragmas"]["cache_size"])
    assert_equal 10000, parsed["default"]["pragmas"]["wal_autocheckpoint"]
    # exactly one pragmas: key was added
    assert_equal 1, result.scan(/^  pragmas:$/).length
  end

  test "apply_pragmas merges into an existing default-level pragmas block" do
    gen = Pu::Lite::TuneGenerator.new([], {}, {})
    result = gen.send(:apply_pragmas, EXISTING_PRAGMAS_DB_YML, ::Gem::Version.new("8.1.0"))

    parsed = render_and_load(result)
    pragmas = parsed["default"]["pragmas"]
    assert_equal "WAL", pragmas["journal_mode"] # preserved
    assert_equal 10000, pragmas["wal_autocheckpoint"] # added
    # no duplicate pragmas: key
    assert_equal 1, result.scan(/^  pragmas:$/).length
  end

  test "apply_pragmas ignores a pragmas block nested under another env and stays valid YAML" do
    gen = Pu::Lite::TuneGenerator.new([], {}, {})
    result = gen.send(:apply_pragmas, PRAGMAS_ELSEWHERE_DB_YML, ::Gem::Version.new("8.1.0"))

    parsed = render_and_load(result) # must not raise
    # default got its own pragmas
    assert_equal 10000, parsed["default"]["pragmas"]["wal_autocheckpoint"]
    # the production.primary pragmas is untouched
    assert_equal "WAL", parsed["production"]["primary"]["pragmas"]["journal_mode"]
  end

  # Test Maintenance Generator
  test "maintenance generator exists and has correct namespace" do
    assert defined?(Pu::Lite::MaintenanceGenerator)
    assert Pu::Lite::MaintenanceGenerator < Rails::Generators::Base
  end

  test "maintenance generator includes ConfiguresRecurring concern" do
    assert Pu::Lite::MaintenanceGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresRecurring)
  end

  test "maintenance generator has schedule option defaulting to daily 3:30am" do
    options = Pu::Lite::MaintenanceGenerator.class_options
    assert options.key?(:schedule)
    assert_equal "every day at 3:30am", options[:schedule].default
  end

  test "maintenance job template defines the expected constants and behavior" do
    path = File.expand_path(
      "../../lib/generators/pu/lite/maintenance/templates/app/jobs/sqlite_maintenance_job.rb.tt",
      __dir__
    )
    job = File.read(path)

    assert_includes job, "class MaintenanceConnection < ActiveRecord::Base"
    assert_includes job, "OPTIMIZE_DBS"
    assert_includes job, "VACUUM_DBS = %w[primary errors rails_pulse]"
    assert_includes job, "PRAGMA optimize"
    assert_includes job, "VACUUM"
    assert_includes job, "Rails.error.report"
  end

  test "maintenance task yaml uses the schedule option and is valid YAML" do
    require "yaml"
    gen = Pu::Lite::MaintenanceGenerator.new([], {schedule: "*/30 * * * *"}, {})
    yaml = gen.send(:maintenance_task_yaml)

    parsed = YAML.safe_load(yaml)
    assert_equal "SqliteMaintenanceJob", parsed["sqlite_maintenance"]["class"]
    assert_equal "*/30 * * * *", parsed["sqlite_maintenance"]["schedule"]
  end
end
