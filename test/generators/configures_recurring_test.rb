# frozen_string_literal: true

require "test_helper"
require "yaml"
require "generators/pu/lib/plutonium_generators"

class ConfiguresRecurringTest < ActiveSupport::TestCase
  RecurringYAML = PlutoniumGenerators::Concerns::ConfiguresRecurring::RecurringYAML

  ENV_SCOPED = <<~YAML
    production:
      existing_task:
        class: ExistingJob
        schedule: every hour

    development:
      existing_task:
        class: ExistingJob
        schedule: every hour
  YAML

  FLAT = <<~YAML
    existing_task:
      class: ExistingJob
      schedule: every hour
  YAML

  TASKS = <<~YAML
    sqlite_maintenance:
      class: SqliteMaintenanceJob
      schedule: every day at 3:30am
  YAML

  test "injects tasks under every environment in an env-scoped file" do
    result = RecurringYAML.new.inject(ENV_SCOPED, TASKS)

    assert_equal 2, result.scan(/sqlite_maintenance:/).length
    assert_match(/^  sqlite_maintenance:$/, result)
    assert_includes result, "existing_task:"
  end

  test "appends tasks to a flat (non-env-scoped) file" do
    result = RecurringYAML.new.inject(FLAT, TASKS)

    assert_equal 1, result.scan(/sqlite_maintenance:/).length
    assert_match(/^sqlite_maintenance:$/, result)
    assert_includes result, "existing_task:"
  end

  RP_TASKS = <<~YAML
    rails_pulse_summary:
      class: RailsPulse::SummaryJob
      queue: default
      schedule: every hour at minute 5
      description: "Roll up Rails Pulse raw records into summary tables"

    rails_pulse_cleanup:
      class: RailsPulse::CleanupJob
      queue: default
      schedule: every day at 1am
      description: "Archive/purge old Rails Pulse data"
  YAML

  test "inject adds entries inside each env block" do
    content = <<~YAML
      production:
        existing_job:
          class: Foo
          schedule: every hour

      development:
        dev_job:
          class: Bar
          schedule: every day at 9am
    YAML

    result = RecurringYAML.new.inject(content, RP_TASKS)
    parsed = YAML.safe_load(result)

    assert_equal %w[dev_job rails_pulse_cleanup rails_pulse_summary],
      parsed["development"].keys.sort
    assert_equal %w[existing_job rails_pulse_cleanup rails_pulse_summary],
      parsed["production"].keys.sort
    assert_equal "RailsPulse::SummaryJob", parsed["production"]["rails_pulse_summary"]["class"]
    assert_equal "RailsPulse::CleanupJob", parsed["development"]["rails_pulse_cleanup"]["class"]
  end

  test "inject preserves existing entries verbatim" do
    content = <<~YAML
      production:
        existing_job:
          class: Foo
          schedule: every hour
    YAML

    result = RecurringYAML.new.inject(content, RP_TASKS)

    assert_includes result, "existing_job:\n    class: Foo\n    schedule: every hour"
  end

  test "inject respects nonstandard indent" do
    content = "production:\n    deep:\n        class: Foo\n        schedule: every hour\n"

    result = RecurringYAML.new.inject(content, RP_TASKS)

    assert_match(/^    rails_pulse_summary:/, result)
    assert_match(/^      class: RailsPulse::SummaryJob/, result)
    parsed = YAML.safe_load(result)
    assert_equal "RailsPulse::SummaryJob", parsed["production"]["rails_pulse_summary"]["class"]
  end

  test "inject only touches recognized env keys" do
    content = <<~YAML
      production:
        job:
          class: Foo
          schedule: every hour

      shared_anchors:
        something:
          class: Bar
          schedule: every hour
    YAML

    result = RecurringYAML.new.inject(content, RP_TASKS)
    parsed = YAML.safe_load(result)

    assert_includes parsed["production"].keys, "rails_pulse_summary"
    refute_includes parsed["shared_anchors"].keys, "rails_pulse_summary"
  end
end
