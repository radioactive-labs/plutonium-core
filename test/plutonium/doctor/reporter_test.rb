# frozen_string_literal: true

require "test_helper"
require "stringio"

class Plutonium::Doctor::ReporterTest < Minitest::Test
  Reporter = Plutonium::Doctor::Reporter
  Report = Plutonium::Doctor::Report
  Finding = Plutonium::Doctor::Finding

  def test_prints_findings_worst_first
    output = render(findings: [warning, error])

    assert_operator output.index("ERROR"), :<, output.index("WARNING")
  end

  def test_groups_findings_of_the_same_check_together
    output = render(findings: [error, error("Blogging::Post#archive")])

    assert_includes output, "missing_policy_rule"
    assert_equal 1, output.scan(/^ERROR/).size
    assert_includes output, "(2)"
  end

  def test_prints_the_suppression_key_under_every_finding
    output = render(findings: [error])

    assert_includes output, "missing_policy_rule:Blogging::Post#publish"
  end

  def test_names_the_portals_a_finding_was_seen_in
    output = render(findings: [error])

    assert_includes output, "AdminPortal, OrgPortal"
  end

  def test_summarises_counts_and_what_was_looked_at
    output = render(findings: [error, warning])

    assert_includes output, "1 error, 1 warning"
    assert_includes output, "3 resources across 2 portals"
  end

  def test_says_so_plainly_when_there_is_nothing_to_report
    output = render(findings: [])

    assert_includes output, "No problems found"
  end

  # "Nothing was wrong" and "nothing was looked at" are different answers, and a
  # checker that renders them alike is how a CI job passes without running.
  def test_distinguishes_a_clean_run_from_an_empty_one
    output = render(findings: [], resources: 0, portals: 0)

    assert_includes output, "No Plutonium resources found"
    refute_includes output, "No problems found"
  end

  def test_emits_no_escape_codes_when_colour_is_off
    refute_includes render(findings: [error]), "\e["
  end

  private

  def error(subject = "Blogging::Post#publish")
    Finding.new(
      check: :missing_policy_rule,
      severity: :error,
      subject: subject,
      message: "`publish` has no `publish?`",
      details: "Add the predicate.",
      scope: ["AdminPortal", "OrgPortal"]
    )
  end

  def warning
    Finding.new(
      check: :redundant_field_declaration,
      severity: :warning,
      subject: "PostDefinition#field:title",
      message: "`field :title` declares nothing",
      details: "Delete the line.",
      scope: "AdminPortal"
    )
  end

  def render(findings:, resources: 3, portals: 2)
    io = StringIO.new
    report = Report.new(
      findings: findings,
      portals_inspected: portals,
      resources_inspected: resources,
      checks_run: [:missing_policy_rule]
    )
    Reporter.new(report, io: io, color: false).call
    io.string
  end
end
