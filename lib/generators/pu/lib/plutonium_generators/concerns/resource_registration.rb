# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    module ResourceRegistration
      private

      # Insert `register_resource ::<Klass>` into a routes file. Idempotent:
      # skips if already present. Falls back when the conventional
      # `# register resources above.` marker is missing.
      def register_resource_in_routes(routes_path, resource, singular: false)
        line = "register_resource ::#{resource}"
        line += ", singular: true" if singular
        content = File.read(File.join(destination_root, routes_path))

        if /^\s*#{Regexp.escape(line)}\b/.match?(content)
          say_status :identical, "#{routes_path} already registers #{resource}", :blue
          return
        end

        if /^\s*#\s*register resources above\b/.match?(content)
          insert_into_file routes_path,
            indent("#{line}\n", 2),
            before: /^\s*#\s*register resources above\b.*/
        elsif /^\s*Rails\.application\.routes\.draw do\b/.match?(content)
          insert_into_file routes_path,
            indent("#{line}\n", 2),
            after: /^\s*Rails\.application\.routes\.draw do.*\n/
        elsif (match = content.match(/^(\w+::Engine)\.routes\.draw do.*\n/))
          insert_into_file routes_path,
            indent("#{line}\n", 2),
            after: /^\s*#{Regexp.escape(match[1])}\.routes\.draw do.*\n/
        else
          say_status :warn,
            "Could not locate routes block in #{routes_path}; add manually: #{line}",
            :yellow
        end
      end
    end
  end
end
