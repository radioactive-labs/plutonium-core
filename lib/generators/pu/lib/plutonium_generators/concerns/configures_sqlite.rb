# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    # What a SQLite app adds to ConfiguresDatabase: its databases are files that
    # share one definition, anchored under `default`.
    module ConfiguresSqlite
      class DatabaseYAML < ConfiguresDatabase::DatabaseYAML
        def new_database(name, migrations_paths: nil, schema_dump: nil)
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
          unless schema_dump.nil?
            db.children.concat [
              Psych::Nodes::Scalar.new("schema_dump"),
              Psych::Nodes::Scalar.new(schema_dump.to_s)
            ]
          end
          "\n" + emit_pair(Psych::Nodes::Scalar.new(name), db)
        end

        # Points each environment at the shared definition.
        def add_database(name, migrations_paths: nil, schema_dump: nil)
          environments.filter_map do |scalar, mapping|
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

            [scalar.value, emit_pair(scalar, mapping), emit_pair(scalar, new_mapping)]
          end
        end
      end
    end
  end
end
