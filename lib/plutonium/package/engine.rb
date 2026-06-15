module Plutonium
  module Package
    module Engine
      extend ActiveSupport::Concern

      included do
        # Prevent this package's app/views from being appended to the global
        # ActionController/ActionMailer view lookup — Plutonium resolves package
        # views at the controller level (see Plutonium::Core::Controllers::Bootable,
        # which reads current_engine.paths["app/views"]). We neutralize the
        # engine's built-in `add_view_paths` initializer rather than clearing
        # config.paths["app/views"], which that controller-level resolver needs.
        #
        # This MUST run as a real initializer (before :add_view_paths), NOT in
        # before_configuration: that hook can fire before sibling package engines
        # are loaded (it does in development, where :before_configuration has
        # already run by the time config/packages.rb loads). Touching
        # Rails.application.initializers there forces Rails.application.railties
        # to memoize early — with only the packages loaded so far — permanently
        # dropping the rest from the autoload paths (e.g. `uninitialized constant
        # Blogging::Post`). By initializer-run time, railties is fully populated.
        initializer :plutonium_neutralize_add_view_paths, before: :add_view_paths do
          add_view_paths_initializer = Rails.application.initializers.find do |a|
            a.context_class == self.class && a.name.to_s == "add_view_paths"
          end
          add_view_paths_initializer&.instance_variable_set(:@block, ->(app) {})
        end

        initializer :append_migrations do |app|
          unless app.root.to_s.match root.to_s
            config.paths["db/migrate"].expanded.each do |expanded_path|
              app.config.paths["db/migrate"] << expanded_path
              ActiveRecord::Migrator.migrations_paths << expanded_path
            end
          end
        end
      end
    end
  end
end
