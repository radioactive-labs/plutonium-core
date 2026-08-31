# frozen_string_literal: true

require "test_helper"

class Plutonium::Doctor::RunnerTest < Minitest::Test
  include DoctorHelpers

  Runner = Plutonium::Doctor::Runner
  Config = Plutonium::Doctor::Config

  def setup
    Rails.application.eager_load!
    Rails.application.reload_routes!
  end

  def test_inspects_the_portals_and_resources_of_the_application
    report = run_doctor

    assert_operator report.portals_inspected, :>, 0
    assert_operator report.resources_inspected, :>, 0
    refute report.nothing_inspected?
  end

  def test_the_dummy_application_has_no_errors
    # A standing assertion about the fixture app as much as about the doctor:
    # an error appearing here means either a real mistake in test/dummy or a
    # check that is wrong about the framework's own output.
    report = run_doctor

    assert_empty report.errors.map(&:message)
  end

  # Uses a fixture check rather than whatever the dummy app happens to declare,
  # so tidying a definition in test/dummy cannot quietly stop exercising dedupe.
  def test_folds_one_mistake_reached_through_several_portals_into_one_finding
    report = run_doctor(checks: [ConstantCheck])
    keys = report.findings.map(&:key)

    assert_equal keys.uniq, keys, "findings should be unique by key"

    shared = report.findings.find { |f| f.scopes.size > 1 }
    refute_nil shared, "a resource mounted in two portals should yield one finding naming both"
    assert_operator report.resources_inspected, :>, report.findings.size
  end

  def test_real_findings_are_also_unique_by_key
    keys = run_doctor.findings.map(&:key)

    assert_equal keys.uniq, keys
  end

  def test_a_disabled_check_never_runs
    report = run_doctor(config: Config.new(disabled: [:redundant_field_declaration]))

    assert_empty report.findings.select { |f| f.check == :redundant_field_declaration }
    refute_includes report.checks_run, :redundant_field_declaration
  end

  def test_an_ignored_key_is_dropped_from_the_report
    key = run_doctor(checks: [ConstantCheck]).findings.first.key

    report = run_doctor(checks: [ConstantCheck], config: Config.new(ignored: [key]))

    refute_includes report.findings.map(&:key), key
  end

  def test_restricting_to_one_portal_narrows_the_run
    report = run_doctor(only: "admin_portal")

    assert_equal 1, report.portals_inspected
    assert report.findings.all? { |f| f.scopes == ["AdminPortal"] }
  end

  # disable also applies to the checks the runner raises itself, which are not
  # in CHECKS and so cannot be filtered out of the check list.
  def test_disable_covers_a_runner_owned_check_too
    report = run_doctor(checks: [ExplodingCheck], config: Config.new(disabled: [:check_failed]))

    assert_empty report.findings
  end

  def test_a_check_that_raises_is_reported_rather_than_taking_the_run_down
    report = run_doctor(checks: [ExplodingCheck])

    assert_operator report.findings.size, :>, 0
    assert report.findings.all? { |f| f.check == :check_failed }
    assert_match(/could not run/, report.findings.first.message)
    assert_match(/deliberate/, report.findings.first.details)
  end

  def test_pass_depends_on_strictness_when_only_warnings_are_present
    report = run_doctor

    assert_empty report.errors
    assert report.pass?
    refute report.pass?(strict: true) if report.warnings.any?
  end

  def test_skips_plutonium_own_resources
    # Async::Run is registered like any other resource; a finding against it is
    # a bug to fix in the gem, not something an application can act on.
    report = run_doctor

    refute report.findings.any? { |f| f.subject.include?("Plutonium::") }
  end

  private

  def run_doctor(only: nil, config: Config.new, checks: Runner::CHECKS)
    Runner.new(only: only, config: config, checks: checks).call
  end

  # Reports once per resource, with a key that does not vary by portal — the
  # shape a shared definition produces when several portals mount it.
  class ConstantCheck < Plutonium::Doctor::Check
    def self.check_name = :constant

    def call
      [finding(subject: target.resource_class.name, message: "always")]
    end
  end

  class ExplodingCheck < Plutonium::Doctor::Check
    def self.check_name = :exploding

    def call
      raise "deliberate failure"
    end
  end
end
