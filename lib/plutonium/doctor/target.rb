# frozen_string_literal: true

module Plutonium
  module Doctor
    # A resource as one portal sees it.
    #
    # Definition and policy are resolved the way a request resolves them —
    # portal namespace first, top level as the fallback — so the doctor
    # inspects the classes that would actually serve the request rather than
    # the top-level pair a portal may have overridden. See
    # {Plutonium::Resource::Controller#resource_definition} for the definition
    # rule and ActionPolicy's namespaced lookup for the policy one.
    class Target
      attr_reader :portal, :resource_class, :definition_class, :policy_class

      def initialize(portal:, resource_class:, definition_class:, policy_class:)
        @portal = portal
        @resource_class = resource_class
        @definition_class = definition_class
        @policy_class = policy_class
      end

      # Definitions are cheap to build and every check wants the merged,
      # instance-level view (`defined_actions`, `defined_fields`, …), which only
      # exists on an instance.
      def definition
        @definition ||= definition_class.new
      end

      # Whether this target is framework-owned rather than application code.
      # Plutonium registers resources of its own (Async::Run being the obvious
      # one) and the doctor has nothing useful to say about them: a finding
      # there is a bug to fix in the gem, not something an application can act
      # on from its own config.
      def framework_owned?
        definition_class.name.to_s.start_with?("Plutonium::") ||
          resource_class.name.to_s.start_with?("Plutonium::")
      end
    end
  end
end
