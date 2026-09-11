# frozen_string_literal: true

module Plutonium
  module Doctor
    # The portals of a booted application, and what each registered.
    #
    # Traversal mirrors Pu::Core::TypespecGenerator: portal engines come from
    # Rails::Engine.subclasses, resources from each engine's own register. Going
    # portal by portal rather than straight down the register matters, because
    # a portal can override both the definition and the policy for a resource —
    # inspecting only the top-level pair would check classes that never serve a
    # request.
    class Portals
      Portal = Struct.new(:name, :engine, :namespace, :resources)

      # @param only [String, nil] restrict to one portal, by underscored name
      def self.discover(only: nil) = new(only: only).call

      def initialize(only: nil)
        @only = only
      end

      def call
        engines.filter_map do |engine|
          name = engine.name.sub(/::Engine$/, "")
          next if @only && name.underscore != @only.to_s.underscore

          Portal.new(
            name: name,
            engine: engine,
            namespace: engine.module_parent,
            resources: resources_for(engine)
          )
        end
      end

      private

      def engines
        Rails::Engine.subclasses.select do |engine|
          engine.name.present? &&
            engine.included_modules.any? { |mod| mod.name&.include?("Plutonium::Portal") }
        end
      end

      def resources_for(engine)
        engine.resource_register.resources
      rescue => e
        # A register that cannot be read is a boot problem, not something the
        # doctor should crash on halfway through a report.
        Plutonium.logger&.warn { "[plutonium doctor] could not read register for #{engine}: #{e.message}" }
        []
      end
    end
  end
end
