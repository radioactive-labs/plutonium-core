# frozen_string_literal: true

require "erb"
require "yaml"
require "rails/generators"
require "generators/pu/lib/plutonium_generators"

# Runs the lite generators' database.yml edit against a real file on disk.
module DatabaseYmlHelper
  POSTGRES_TEMPLATE = File.expand_path("../../lib/generators/pu/service/postgres/templates/database.yml.tt", __dir__)

  class Editor < Rails::Generators::Base
    include PlutoniumGenerators::Generator
    include PlutoniumGenerators::Concerns::ConfiguresDatabase

    def add(name, **options)
      add_secondary_database(name, **options)
    end
  end

  # The database.yml `pu:service:postgres` writes.
  def postgres_database_yml
    ERB.new(File.read(POSTGRES_TEMPLATE)).result_with_hash(db_prefix: "app")
  end

  # Yields a directory holding config/database.yml with the given content.
  def with_database_yml(content)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/database.yml"), content)
      yield dir
    end
  end

  # One editor per database, as each generator is its own process (an editor
  # caches its parse of database.yml).
  # Returns what the generator printed.
  def add_secondary_database(dir, name, **options)
    capture_io { Editor.new([], {}, destination_root: dir).add(name, **options) }.first
  end

  def read_database_yml(dir)
    File.read(File.join(dir, "config/database.yml"))
  end

  def load_database_yml(dir)
    YAML.safe_load(ERB.new(read_database_yml(dir)).result, aliases: true)
  end
end
