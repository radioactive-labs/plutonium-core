# frozen_string_literal: true

require "psych"

module PlutoniumGenerators
  module Concerns
    # Adds a database for a Solid* / engine to config/database.yml, whatever the
    # primary is. The edit itself is the DatabaseYAML's: this base one makes
    # another database on the primary's server, ConfiguresSqlite::DatabaseYAML
    # makes a SQLite file.
    module ConfiguresDatabase
      class DatabaseYAML
        COMMENTED_PROD_DATABASE = "# database: path/to/persistent/storage/production.sqlite3"
        UNCOMMENTED_PROD_DATABASE = "database: path/to/persistent/storage/production.sqlite3"

        # The editor that matches the file's `default` adapter.
        def self.for(path)
          yaml = new(path: path)
          yaml.sqlite? ? ConfiguresSqlite::DatabaseYAML.new(path: path) : yaml
        end

        attr_reader :content

        def initialize(path:)
          @content = File.read(path)
          # if the production environment has the default commented database value,
          # uncomment it so that the value can be parsed
          @content.gsub!(COMMENTED_PROD_DATABASE, UNCOMMENTED_PROD_DATABASE)
          @stream = Psych.parse_stream(@content)
          @emission_stream = Psych::Nodes::Stream.new
          @emission_document = Psych::Nodes::Document.new
          @emission_mapping = Psych::Nodes::Mapping.new
        end

        # Adapter named by the `default: &default` block, or nil when absent.
        def default_adapter
          default = mapping_value(root, "default")
          default && mapping_value(default, "adapter")&.value
        end

        def sqlite?
          default_adapter.nil? || default_adapter.include?("sqlite")
        end

        # A definition shared by every environment, to insert after `default`.
        # A server database has none: each environment carries its own.
        def new_database(name, migrations_paths: nil, schema_dump: nil)
        end

        def database_def_regex(name)
          /#{name}: &#{name}\n(?:[ \t]+.*\n)+/
        end

        # Gives each environment its own `name` entry, copied from that
        # environment's primary with the database name suffixed
        # (`app_development` -> `app_development_queue`), as stock Rails lays out
        # production. An environment that already has a `name` entry is left
        # alone, so re-running is a no-op.
        #
        # Returns [environment, old_text, new_text] per environment; new_text is
        # nil when the primary has no literal database name to derive one from.
        def add_database(name, migrations_paths: nil, schema_dump: nil)
          migrations_paths ||= "db/#{name}_migrate"
          environments.filter_map do |scalar, mapping|
            next if mapping_value(mapping, name)

            primary = mapping_value(mapping, "primary")
            next unless primary || mapping_value(mapping, "database") || mapping_value(mapping, "<<")

            entry = server_database_entry(primary || mapping, name, migrations_paths, schema_dump)
            next [scalar.value] unless entry

            new_mapping = Psych::Nodes::Mapping.new
            new_mapping.children.concat(primary ? mapping.children : [Psych::Nodes::Scalar.new("primary"), mapping])
            new_mapping.children.concat [Psych::Nodes::Scalar.new(name), entry]

            [scalar.value, emit_pair(scalar, mapping), emit_pair(scalar, new_mapping)]
          end
        end

        private

        def root
          @stream.children.first.root
        end

        # [name, mapping] for each top-level environment (anchored blocks such
        # as `default` are not environments).
        def environments
          root.children.each_slice(2).select do |scalar, mapping|
            scalar.is_a?(Psych::Nodes::Scalar) && mapping.is_a?(Psych::Nodes::Mapping) && mapping.anchor.to_s.empty?
          end
        end

        # The value node for `key` in a mapping, or nil.
        def mapping_value(mapping, key)
          mapping.children.each_slice(2).find { |k, _| k.is_a?(Psych::Nodes::Scalar) && k.value == key }&.last
        end

        # `primary`'s settings with `database` suffixed, or nil when `primary`
        # has no literal database name to derive one from.
        def server_database_entry(primary, name, migrations_paths, schema_dump)
          database = mapping_value(primary, "database")
          return unless database.is_a?(Psych::Nodes::Scalar)

          settings = primary.children.each_slice(2).flat_map do |k, v|
            next [] if %w[migrations_paths schema_dump].include?(k.value)

            [k, v.equal?(database) ? Psych::Nodes::Scalar.new("#{database.value}_#{name}") : v]
          end
          extras = {"migrations_paths" => migrations_paths, "schema_dump" => schema_dump&.to_s}.compact
          extras.each { |k, v| settings.push(Psych::Nodes::Scalar.new(k), Psych::Nodes::Scalar.new(v)) }

          Psych::Nodes::Mapping.new.tap { |entry| entry.children.concat settings }
        end

        def emit_pair(scalar, mapping)
          @emission_mapping.children.clear.concat [scalar, mapping]
          @emission_document.children.clear.concat [@emission_mapping]
          @emission_stream.children.clear.concat [@emission_document]
          output = @emission_stream.yaml.gsub!(/^---/, "").strip!
          output.gsub!(UNCOMMENTED_PROD_DATABASE, COMMENTED_PROD_DATABASE)
          output
        end
      end

      private

      def database_yaml
        @database_yaml ||= DatabaseYAML.for(File.expand_path("config/database.yml", destination_root))
      end

      def add_secondary_database(name, migrations_paths: nil, schema_dump: nil)
        options = {migrations_paths: migrations_paths, schema_dump: schema_dump}

        if (definition = database_yaml.new_database(name, **options))
          insert_into_file "config/database.yml",
            definition + "\n",
            after: database_yaml.database_def_regex("default"),
            verbose: false,
            force: false
          say_status :def_db, "#{name} (database.yml)"
        end

        database_yaml.add_database(name, **options).each do |environment, old_entry, new_entry|
          if new_entry.nil?
            say_status :skip, "#{name} -> #{environment}: no literal `database:` in its primary, add it by hand", :yellow
            next
          end

          gsub_file("config/database.yml", old_entry, verbose: false) { new_entry }
          if file_includes?("config/database.yml", new_entry)
            say_status :add_db, "#{name} -> #{environment} (database.yml)"
          else
            say_status :error, "#{name} -> #{environment}: could not edit database.yml (comments between its keys?), add it by hand", :red
          end
        end
      end

      def prepare_database(name)
        Bundler.with_unbundled_env do
          run "bin/rails db:prepare", env: {"DATABASE" => name}
        end
      end

      def add_application_config(config_line, after_pattern: nil)
        return if file_includes?("config/application.rb", config_line)

        pattern = after_pattern || /^([ \t]*).*?(?=\n\s*end\nend)$/
        insert_into_file "config/application.rb", after: pattern do
          if after_pattern
            "\n\\1#{config_line}"
          else
            "\n\n\\1#{config_line}"
          end
        end
      end
    end
  end
end
