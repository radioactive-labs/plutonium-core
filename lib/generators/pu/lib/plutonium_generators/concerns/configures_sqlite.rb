# frozen_string_literal: true

require "psych"

module PlutoniumGenerators
  module Concerns
    module ConfiguresSqlite
      class DatabaseYAML
        COMMENTED_PROD_DATABASE = "# database: path/to/persistent/storage/production.sqlite3"
        UNCOMMENTED_PROD_DATABASE = "database: path/to/persistent/storage/production.sqlite3"

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

        def add_database(name)
          root = @stream.children.first.root
          root.children.each_slice(2).map do |scalar, mapping|
            next unless scalar.is_a?(Psych::Nodes::Scalar)
            next unless mapping.is_a?(Psych::Nodes::Mapping)
            next unless mapping.anchor.nil? || mapping.anchor.empty?
            next if mapping.children.each_slice(2).any? do |key, value|
              key.is_a?(Psych::Nodes::Scalar) && key.value == name && value.is_a?(Psych::Nodes::Alias) && value.anchor == name
            end

            new_mapping = Psych::Nodes::Mapping.new
            if mapping.children.first.value == "<<" # 2-tiered environment
              new_mapping.children.concat [
                Psych::Nodes::Scalar.new("primary"),
                mapping,
                Psych::Nodes::Scalar.new(name),
                Psych::Nodes::Alias.new(name)
              ]
            else # 3-tiered environment
              new_mapping.children.concat mapping.children
              new_mapping.children.concat [
                Psych::Nodes::Scalar.new(name),
                Psych::Nodes::Alias.new(name)
              ]
            end

            old_environment_entry = emit_pair(scalar, mapping)
            new_environment_entry = emit_pair(scalar, new_mapping)

            [scalar.value, old_environment_entry, new_environment_entry]
          end.compact!
        end

        def new_database(name, migrations_paths: nil)
          migrations_paths ||= "db/#{name}_migrate"
          db = Psych::Nodes::Mapping.new(name)
          db.children.concat [
            Psych::Nodes::Scalar.new("<<"),
            Psych::Nodes::Alias.new("default"),
            Psych::Nodes::Scalar.new("migrations_paths"),
            Psych::Nodes::Scalar.new(migrations_paths),
            Psych::Nodes::Scalar.new("database"),
            Psych::Nodes::Scalar.new("storage/<%= Rails.env %>-#{name}.sqlite3")
          ]
          "\n" + emit_pair(Psych::Nodes::Scalar.new(name), db)
        end

        def database_def_regex(name)
          /#{name}: &#{name}\n(?:[ \t]+.*\n)+/
        end

        private

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
        @database_yaml ||= DatabaseYAML.new(path: File.expand_path("config/database.yml", destination_root))
      end

      def add_sqlite_database(name, migrations_paths: nil)
        # Define the new database configuration
        insert_into_file "config/database.yml",
          database_yaml.new_database(name, migrations_paths: migrations_paths) + "\n",
          after: database_yaml.database_def_regex("default"),
          verbose: false,
          force: false
        say_status :def_db, "#{name} (database.yml)"

        # Add the new database to all environments
        database_yaml.add_database(name)&.each do |environment, old_entry, new_entry|
          gsub_file "config/database.yml", old_entry, new_entry, verbose: false
          say_status :add_db, "#{name} -> #{environment} (database.yml)"
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
