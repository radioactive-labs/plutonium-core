# frozen_string_literal: true

module Plutonium
  module Doctor
    # The result of a run: findings, plus enough context to say what was looked
    # at. "No findings" and "nothing was inspected" print very differently, and
    # conflating them is how a checker ends up quietly passing a CI job it never
    # ran against anything.
    class Report
      attr_reader :findings, :portals_inspected, :resources_inspected, :checks_run, :config

      def initialize(findings:, portals_inspected:, resources_inspected:, checks_run:, config: nil)
        @findings = findings
        @portals_inspected = portals_inspected
        @resources_inspected = resources_inspected
        @checks_run = checks_run
        @config = config
      end

      def errors = findings.select(&:error?)

      def warnings = findings.select(&:warning?)

      def empty? = findings.empty?

      def nothing_inspected? = resources_inspected.zero?

      # Whether the run should be treated as a pass.
      #
      # @param strict [Boolean] when true, warnings fail too
      def pass?(strict: false)
        strict ? findings.empty? : errors.empty?
      end
    end
  end
end
