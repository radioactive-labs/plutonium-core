# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

# Regression: `rails new -d postgresql` followed by the lite generators failed in
# `db:create` with `CREATE DATABASE "storage/development-queue"."sqlite3"`, because
# the new databases were SQLite file paths inheriting the PostgreSQL default.
#
# With a PostgreSQL primary the extra databases must be PostgreSQL too: nothing
# SQLite, no file paths, one database per Solid*/engine on the same server.
class LitePostgresAppTest < ActiveSupport::TestCase
  include DatabaseYmlHelper

  LITE_DATABASES = %w[queue cache cable errors rails_pulse].freeze
  ENVIRONMENTS = %w[development test production].freeze

  RAILS_NEW_FLAGS = %w[
    -d postgresql --skip-bundle --skip-git --skip-test --skip-system-test
    --skip-javascript --skip-asset-pipeline --skip-action-mailer
    --skip-action-mailbox --skip-action-text --skip-active-storage
    --skip-jbuilder --skip-kamal --skip-thruster --skip-rubocop
    --skip-brakeman --skip-ci --skip-dev-gems --skip-bootsnap
  ].freeze

  test "lite databases of a new PostgreSQL app are PostgreSQL databases" do
    Dir.mktmpdir do |tmp|
      app = File.join(tmp, "pg_app")
      output, status = Open3.capture2e("bundle", "exec", "rails", "new", app, *RAILS_NEW_FLAGS,
        chdir: File.expand_path("../..", __dir__))
      assert status.success?, "rails new failed:\n#{output}"
      assert_match(/adapter: postgresql/, read_database_yml(app))

      LITE_DATABASES.each { |name| add_secondary_database(app, name) }

      refute_match(/sqlite/i, read_database_yml(app))

      configs = ActiveRecord::DatabaseConfigurations.new(load_database_yml(app))
      ENVIRONMENTS.each do |env|
        primary = configs.configs_for(env_name: env, name: "primary")
        assert_equal "postgresql", primary.adapter

        LITE_DATABASES.each do |name|
          db = configs.configs_for(env_name: env, name: name)
          assert_equal "postgresql", db.adapter, "#{env}.#{name}"
          assert_equal "#{primary.database}_#{name}", db.database, "#{env}.#{name}"
          assert_equal "db/#{name}_migrate", db.migrations_paths.to_s.sub(/\A.*\/db\//, "db/"), "#{env}.#{name}"
        end
      end
    end
  end
end
