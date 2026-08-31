# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Core
    # Inspects a booted application for the mistakes Plutonium cannot raise on.
    #
    #   bin/rails g pu:core:doctor
    #   bin/rails g pu:core:doctor --strict          # warnings fail too (CI)
    #   bin/rails g pu:core:doctor --portal=admin
    #
    # A generator rather than a rake task only for consistency: everything else
    # a Plutonium developer runs is `bin/rails g pu:…`, and a diagnostic hiding
    # under a different verb is a diagnostic nobody finds. It writes nothing.
    class DoctorGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Check this application for Plutonium mistakes that fail silently"

      class_option :portal, type: :string, desc: "Only inspect this portal"
      class_option :strict, type: :boolean, default: false,
        desc: "Exit non-zero on warnings as well as errors"

      # Rails generators default this to false, which would print the failure
      # and still exit 0 — fine for a generator that has written most of its
      # files, useless for a checker whose entire job in CI is the exit code.
      def self.exit_on_failure? = true

      def start
        load_application

        report = Plutonium::Doctor.run(only: options[:portal])
        Plutonium::Doctor::Reporter.new(report, io: $stdout).call

        return if report.pass?(strict: options[:strict])

        # Thor::Error is how a generator exits non-zero without a backtrace,
        # which is what a CI step wants from a checker.
        raise Thor::Error, failure_message(report)
      end

      private

      def load_application
        Rails.application.eager_load!
        Rails.application.reload_routes!
      end

      def failure_message(report)
        if options[:strict]
          "plutonium doctor: #{report.errors.size} error(s), #{report.warnings.size} warning(s)"
        else
          "plutonium doctor: #{report.errors.size} error(s)"
        end
      end
    end
  end
end
