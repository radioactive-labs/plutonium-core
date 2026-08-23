# frozen_string_literal: true

module Plutonium
  module Doctor
    # One thing worth telling the author about.
    #
    # `subject` is the finding's identity — "Blogging::Post#publish" — and
    # deliberately carries no portal. The same definition is usually reached
    # through several portals, and reporting one mistake three times because
    # three portals mount the resource is noise. Duplicates fold together via
    # {#merge_scope}, which keeps the portal list so the report can still say
    # where it was seen.
    #
    # That identity is also the suppression key, printed verbatim in the report
    # so a line can be pasted straight into `.plutonium-doctor.yml`.
    class Finding
      SEVERITIES = %i[error warning].freeze

      attr_reader :check, :severity, :subject, :message, :details, :scopes

      def initialize(check:, severity:, subject:, message:, details: nil, scope: nil)
        unless SEVERITIES.include?(severity)
          raise ArgumentError, "unknown severity #{severity.inspect}, expected one of #{SEVERITIES.inspect}"
        end

        @check = check.to_sym
        @severity = severity
        @subject = subject.to_s
        @message = message
        @details = details
        @scopes = Array(scope).compact
      end

      # The suppression key, and the identity duplicates fold on.
      # @return [String]
      def key = "#{check}:#{subject}"

      def error? = severity == :error

      def warning? = severity == :warning

      # Folds an identical finding reached through another portal into this one.
      # @param other [Finding]
      # @return [self]
      def merge_scope(other)
        @scopes |= other.scopes
        self
      end
    end
  end
end
