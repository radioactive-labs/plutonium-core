# frozen_string_literal: true

module Plutonium
  module Doctor
    # Runs the checks over every resource of every portal and folds the results
    # into a {Report}.
    #
    # The runner owns everything a check deliberately does not: which portals
    # exist, how a portal resolves a definition and a policy, whether a check is
    # switched off, and how duplicates fold together. A check sees one target
    # and answers about that target.
    class Runner
      CHECKS = [
        Checks::MissingPolicyRule,
        Checks::AutodetectedPermittedAttributes,
        Checks::ConditionAsAuthorization,
        Checks::RedundantFieldDeclaration
      ].freeze

      # @param only [String, nil] restrict to one portal
      # @param config [Config]
      # @param checks [Array<Class>]
      def initialize(only: nil, config: Config.load, checks: CHECKS)
        @only = only
        @config = config
        @checks = checks.reject { |check| config.disabled?(check.check_name) }
      end

      def call
        findings = {}
        resources = 0
        portals = Portals.discover(only: @only)

        portals.each do |portal|
          portal.resources.each do |resource_class|
            target = build_target(portal, resource_class) { |f| record(findings, f) }
            next unless target
            next if target.framework_owned?

            resources += 1
            @checks.each do |check|
              run_check(check, target) { |f| record(findings, f) }
            end
          end
        end

        Report.new(
          findings: findings.values.reject { |f| suppressed?(f) },
          portals_inspected: portals.size,
          resources_inspected: resources,
          checks_run: @checks.map(&:check_name),
          config: @config
        )
      end

      private

      # `disable` is applied to findings as well as to the check list, so that
      # disabling a check the runner raises itself (`unresolvable_resource`,
      # `check_failed`) works the same way as disabling one from CHECKS. A
      # config key that silently does nothing for two of the names it accepts
      # is worse than not accepting them.
      def suppressed?(finding)
        @config.ignored?(finding) || @config.disabled?(finding.check)
      end

      # Folds a finding in by identity, so one mistake reached through three
      # portals is reported once with all three named.
      def record(findings, finding)
        if (existing = findings[finding.key])
          existing.merge_scope(finding)
        else
          findings[finding.key] = finding
        end
      end

      # A check that blows up is reported as a finding rather than taking the
      # whole run down. A doctor that dies on resource four and never mentions
      # resources five through forty is worse than one that says "this check
      # failed here" and keeps going.
      def run_check(check, target)
        check.new(target).call.each { |finding| yield finding }
      rescue => e
        yield Finding.new(
          check: :check_failed,
          severity: :warning,
          subject: "#{target.resource_class}##{check.check_name}",
          message: "#{check.check_name} could not run against #{target.resource_class}",
          details: "#{e.class}: #{e.message}",
          scope: target.portal.name
        )
      end

      # Resolves the definition and policy the way a request in this portal
      # would. Either one missing is itself worth reporting: the resource is
      # registered and routed, so the failure is a 500 on first visit rather
      # than anything the app is protected from.
      def build_target(portal, resource_class)
        definition_class = resolve_definition(portal, resource_class)
        policy_class = resolve_policy(portal, resource_class)

        if definition_class.nil?
          yield unresolvable(portal, resource_class, "definition", "#{resource_class}Definition")
          return nil
        end

        if policy_class.nil?
          yield unresolvable(portal, resource_class, "policy", "#{resource_class}Policy")
          return nil
        end

        Target.new(
          portal: portal,
          resource_class: resource_class,
          definition_class: definition_class,
          policy_class: policy_class
        )
      end

      def unresolvable(portal, resource_class, kind, expected)
        Finding.new(
          check: :unresolvable_resource,
          severity: :error,
          subject: "#{resource_class}##{kind}",
          message: "#{resource_class} is registered in #{portal.name} but has no #{kind} class",
          details: <<~TEXT,
            Expected #{expected}#{" (or #{portal.namespace}::#{expected})" if portal.namespace}.

            The resource is registered and routed, so the first request for it raises.
            Generate the missing class, or drop the `register_resource` line.
          TEXT
          scope: portal.name
        )
      end

      # Mirrors Plutonium::Resource::Controller#resource_definition: portal
      # namespace first, top level as the fallback.
      def resolve_definition(portal, resource_class)
        namespaced = [portal.namespace, "#{resource_class}Definition"].compact.join("::")
        namespaced.safe_constantize || "#{resource_class}Definition".safe_constantize
      end

      def resolve_policy(portal, resource_class)
        ::ActionPolicy.lookup(resource_class, namespace: portal.namespace)
      rescue ::ActionPolicy::NotFound
        nil
      end
    end
  end
end
