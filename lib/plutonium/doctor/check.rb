# frozen_string_literal: true

module Plutonium
  module Doctor
    # Base class for a doctor check.
    #
    # A check is handed one {Target} — a resource as one portal resolves it —
    # and answers with zero or more {Finding}s. It never prints, never decides
    # whether it is enabled, and never looks at other targets; the {Runner}
    # owns all three so that a check stays a pure function of its target and
    # can be unit-tested by constructing a target directly.
    #
    # Subclasses declare a severity and implement {#call}:
    #
    #   class MyCheck < Check
    #     def self.severity = :error
    #
    #     def call
    #       return [] if fine?
    #       [finding(subject: "…", message: "…", details: "…")]
    #     end
    #   end
    class Check
      class << self
        # The name used in reports, in `.plutonium-doctor.yml`, and as the
        # first half of a suppression key. Derived so the two can never drift.
        # @return [Symbol]
        def check_name = name.demodulize.underscore.to_sym

        # @return [Symbol] :error or :warning
        def severity = :warning
      end

      # @param target [Target]
      def initialize(target)
        @target = target
      end

      attr_reader :target

      # @return [Array<Finding>]
      def call
        raise NotImplementedError, "#{self.class} must implement #call"
      end

      private

      def finding(subject:, message:, details: nil)
        Finding.new(
          check: self.class.check_name,
          severity: self.class.severity,
          subject: subject,
          message: message,
          details: details,
          scope: target.portal.name
        )
      end

      # Whether a method on the target's policy is the application's or one of
      # Plutonium's own defaults.
      #
      # Several checks turn on this distinction: an app that never wrote the
      # method has not made a decision, it has inherited one, and inherited
      # defaults are exactly where the silent failures live.
      def app_defined_policy_method?(name)
        return false unless target.policy_class.method_defined?(name) ||
          target.policy_class.private_method_defined?(name)

        owner = target.policy_class.instance_method(name).owner
        !owner.name.to_s.start_with?("Plutonium::", "ActionPolicy::")
      end
    end
  end
end
