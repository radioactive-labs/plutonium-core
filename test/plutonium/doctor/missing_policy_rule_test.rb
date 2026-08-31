# frozen_string_literal: true

require "test_helper"

# A definition with one custom action beyond the CRUD set.
class DoctorPublishDefinition < Plutonium::Resource::Definition
  action :publish, record_action: true
  action :archive, bulk_action: true
end

# Answers for :publish, silent about :archive.
class DoctorHalfCoveredPolicy < Plutonium::Resource::Policy
  def publish? = update?

  def permitted_attributes_for_create = %i[title]

  def permitted_attributes_for_read = %i[title]
end

class DoctorFullyCoveredPolicy < DoctorHalfCoveredPolicy
  def archive? = update?
end

# The shape Plutonium itself generates for a kanban column's enter_interaction.
class DoctorHiddenActionDefinition < Plutonium::Resource::Definition
  action :blocked_enter_interaction, hidden: true
end

class Plutonium::Doctor::MissingPolicyRuleTest < Minitest::Test
  include DoctorHelpers

  Check = Plutonium::Doctor::Checks::MissingPolicyRule

  def test_reports_an_action_with_no_policy_predicate
    findings = run_check(Check, target(DoctorHalfCoveredPolicy))

    assert_equal 1, findings.size
    finding = findings.sole

    assert_equal :missing_policy_rule, finding.check
    assert_equal :error, finding.severity
    assert_equal "Blogging::Post#archive", finding.subject
    assert_match(/`archive` has no `archive\?`/, finding.message)
    assert_match(/DoctorHalfCoveredPolicy/, finding.message)
  end

  def test_says_nothing_when_every_action_is_covered
    assert_empty run_check(Check, target(DoctorFullyCoveredPolicy))
  end

  def test_ignores_the_crud_actions_plutonium_answers_for_itself
    # new/show/edit/destroy are declared by every definition and answered by
    # Plutonium::Resource::Policy, so a bare pairing must stay quiet.
    findings = run_check(Check, target(DoctorFullyCoveredPolicy, definition: Plutonium::Resource::Definition))

    assert_empty findings
  end

  def test_names_the_action_kind_so_the_message_says_what_broke
    finding = run_check(Check, target(DoctorHalfCoveredPolicy)).sole

    assert_match(/Bulk action/, finding.message)
  end

  # `hidden: true` means the action renders on no surface, so the "button that
  # silently never appears" failure cannot happen — and it is how the framework
  # builds a kanban column's enter_interaction, which is predicate-less on
  # purpose because kanban_move? authorizes the drop. Flagging those would make
  # the doctor wrong about every board Plutonium generates.
  def test_exempts_a_hidden_action
    assert_empty run_check(Check, target(DoctorHalfCoveredPolicy, definition: DoctorHiddenActionDefinition))
  end

  def test_carries_the_portal_it_was_seen_in
    finding = run_check(Check, target(DoctorHalfCoveredPolicy, portal: doctor_portal("AdminPortal"))).sole

    assert_equal ["AdminPortal"], finding.scopes
  end

  def test_suppression_key_is_the_check_and_subject
    finding = run_check(Check, target(DoctorHalfCoveredPolicy)).sole

    assert_equal "missing_policy_rule:Blogging::Post#archive", finding.key
  end

  private

  def target(policy_class, definition: DoctorPublishDefinition, portal: doctor_portal)
    doctor_target(
      resource_class: Blogging::Post,
      definition_class: definition,
      policy_class: policy_class,
      portal: portal
    )
  end
end
