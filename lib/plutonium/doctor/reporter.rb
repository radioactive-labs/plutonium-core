# frozen_string_literal: true

module Plutonium
  module Doctor
    # Renders a {Report} as text.
    #
    # Every finding prints its suppression key, because the alternative to an
    # easy suppression is a muted checker. Errors come first, then warnings, and
    # findings of the same check stay together so a systemic mistake reads as
    # one problem rather than fourteen.
    class Reporter
      COLORS = {error: "\e[31m", warning: "\e[33m", dim: "\e[90m", bold: "\e[1m", reset: "\e[0m"}.freeze

      def initialize(report, io: $stdout, color: io.respond_to?(:tty?) && io.tty?)
        @report = report
        @io = io
        @color = color
      end

      def call
        if @report.nothing_inspected?
          @io.puts "No Plutonium resources found to inspect."
          @io.puts dim("Portals are discovered from mounted engines; check that `register_resource` ran.")
          return @report
        end

        %i[error warning].each do |severity|
          grouped(severity).each { |check, findings| print_group(severity, check, findings) }
        end

        print_summary
        @report
      end

      private

      def grouped(severity)
        @report.findings.select { |f| f.severity == severity }.group_by(&:check)
      end

      def print_group(severity, check, findings)
        @io.puts
        @io.puts "#{colorize(severity.to_s.upcase, severity)} #{bold(check.to_s)} #{dim("(#{findings.size})")}"

        findings.each do |finding|
          @io.puts
          @io.puts "  #{finding.message}"
          @io.puts dim("  in #{finding.scopes.join(", ")}") if finding.scopes.any?
          @io.puts
          finding.details.to_s.each_line { |line| @io.puts "    #{line.chomp}" }
          @io.puts dim("    silence with:  #{finding.key}")
        end
      end

      def print_summary
        @io.puts
        @io.puts "─" * 60
        counts = [
          count(@report.errors.size, "error"),
          count(@report.warnings.size, "warning")
        ].join(", ")

        scope = "#{count(@report.resources_inspected, "resource")} across " \
                "#{count(@report.portals_inspected, "portal")}"

        @io.puts @report.empty? ? "No problems found in #{scope}." : "#{counts} in #{scope}."

        if (path = @report.config&.path)
          @io.puts dim("Suppressions from #{path}.")
        end
      end

      def count(number, noun) = "#{number} #{noun.pluralize(number)}"

      def colorize(text, key) = @color ? "#{COLORS[key]}#{text}#{COLORS[:reset]}" : text

      def bold(text) = colorize(text, :bold)

      def dim(text) = colorize(text, :dim)
    end
  end
end
