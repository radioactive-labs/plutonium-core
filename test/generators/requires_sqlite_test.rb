# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "rails/generators"

%w[setup tune litestream maintenance].each { |name| require "generators/pu/lite/#{name}/#{name}_generator" }

# The SQLite-only generators do nothing on an app whose primary database is not
# SQLite, so nothing SQLite is generated for it.
class RequiresSqliteTest < ActiveSupport::TestCase
  include DatabaseYmlHelper

  SQLITE_ONLY = [
    Pu::Lite::SetupGenerator,
    Pu::Lite::TuneGenerator,
    Pu::Lite::LitestreamGenerator,
    Pu::Lite::MaintenanceGenerator
  ].freeze

  def generator(klass, dir)
    klass.new([], {}, destination_root: dir)
  end

  test "every SQLite-only generator skips a PostgreSQL app" do
    with_database_yml(postgres_database_yml) do |dir|
      SQLITE_ONLY.each do |klass|
        out, = capture_io { refute generator(klass, dir).send(:sqlite_primary?), klass.name }
        assert_match(/#{klass.name.demodulize} is SQLite only \(primary database is postgresql\)/, out)
      end
    end
  end

  test "every SQLite-only generator runs on a SQLite app, or when there is no database.yml" do
    with_database_yml("default: &default\n  adapter: sqlite3\n") do |dir|
      SQLITE_ONLY.each { |klass| assert generator(klass, dir).send(:sqlite_primary?), klass.name }
    end
    Dir.mktmpdir do |dir|
      SQLITE_ONLY.each { |klass| assert generator(klass, dir).send(:sqlite_primary?), klass.name }
    end
  end

  test "tune leaves a PostgreSQL database.yml alone" do
    with_database_yml(postgres_database_yml) do |dir|
      capture_io { generator(Pu::Lite::TuneGenerator, dir).start }

      assert_equal postgres_database_yml, read_database_yml(dir)
    end
  end

  test "maintenance installs no job on a PostgreSQL app" do
    with_database_yml(postgres_database_yml) do |dir|
      capture_io { generator(Pu::Lite::MaintenanceGenerator, dir).start }

      refute File.exist?(File.join(dir, "app/jobs/sqlite_maintenance_job.rb"))
    end
  end
end
