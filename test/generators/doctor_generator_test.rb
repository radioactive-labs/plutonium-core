# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/pu/core/doctor/doctor_generator"

class DoctorGeneratorTest < Rails::Generators::TestCase
  tests Pu::Core::DoctorGenerator
  destination Rails.root

  # The generator writes nothing, so there is no dummy app state to restore —
  # it is a reporter with an exit code, shaped as a generator only so it is
  # found where every other Plutonium command is.
  def setup
  end

  def test_prints_a_report_for_the_application
    output = run_generator

    assert_match(/resources across/, output)
    assert_match(/\d+ errors?, \d+ warnings?|No problems found/, output)
  end

  def test_restricting_to_one_portal_narrows_the_run
    output = run_generator ["--portal=admin_portal"]

    assert_match(/across 1 portal/, output)
  end

  # The exit code is the whole point of --strict: a CI step that reports and
  # then exits 0 is a CI step that never fails.
  def test_strict_exits_non_zero_on_warnings
    error = assert_raises(SystemExit) { run_generator ["--strict"] }

    refute_equal 0, error.status
  end

  def test_without_strict_warnings_do_not_fail_the_run
    run_generator

    pass
  end
end
