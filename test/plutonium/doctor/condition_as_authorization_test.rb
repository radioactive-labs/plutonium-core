# frozen_string_literal: true

require "test_helper"

class DoctorConditionDefinition < Plutonium::Resource::Definition
  # Reads as an authorization rule.
  action :publish, record_action: true, condition: -> { current_user.admin? }
  # Reads as presentation.
  action :preview, record_action: true, condition: -> { object&.draft? }
  # No condition at all.
  action :syndicate, record_action: true
end

# Every custom predicate delegates: written by the application, but answering a
# different question than the condition asks.
class DoctorDelegatingPolicy < Plutonium::Resource::Policy
  def publish? = update?

  def preview? = update?

  def syndicate? = update?
end

# publish? decides for itself, on the user.
class DoctorDecidingPolicy < DoctorDelegatingPolicy
  def publish? = user.admin?
end

class Plutonium::Doctor::ConditionAsAuthorizationTest < Minitest::Test
  include DoctorHelpers

  Check = Plutonium::Doctor::Checks::ConditionAsAuthorization

  def test_reports_a_condition_that_is_the_only_user_check
    finding = run_check(Check, target(DoctorDelegatingPolicy)).sole

    assert_equal :condition_as_authorization, finding.check
    assert_equal :warning, finding.severity
    assert_equal "Blogging::Post#publish", finding.subject
    assert_match(/checks the user in `condition:`/, finding.message)
  end

  def test_quotes_the_condition_so_the_reader_can_judge_it
    finding = run_check(Check, target(DoctorDelegatingPolicy)).sole

    assert_match(/current_user\.admin\?/, finding.details)
    assert_match(/route stays live/, finding.details)
  end

  def test_leaves_a_presentation_condition_alone
    subjects = run_check(Check, target(DoctorDelegatingPolicy)).map(&:subject)

    refute_includes subjects, "Blogging::Post#preview"
  end

  def test_leaves_an_action_with_no_condition_alone
    subjects = run_check(Check, target(DoctorDelegatingPolicy)).map(&:subject)

    refute_includes subjects, "Blogging::Post#syndicate"
  end

  # The case the first cut of this check missed: the app DID write publish?, so
  # an owner-based test goes quiet, but a bare delegation checks nothing about
  # the user and the condition is still the only gate.
  def test_a_delegating_predicate_does_not_count_as_deciding
    finding = run_check(Check, target(DoctorDelegatingPolicy)).sole

    assert_equal "Blogging::Post#publish", finding.subject
  end

  def test_says_nothing_once_the_policy_checks_the_user_itself
    assert_empty run_check(Check, target(DoctorDecidingPolicy))
  end

  # A CRUD action hidden by a condition while the inherited predicate still
  # allows it — same bug, reached through the framework's own actions.
  def test_reports_a_crud_action_hidden_by_a_condition
    findings = run_check(Check, target(DoctorDelegatingPolicy, definition: DoctorHiddenDestroyDefinition))

    assert_equal "Blogging::Post#destroy", findings.sole.subject
  end

  # A missing predicate belongs to MissingPolicyRule.
  def test_defers_a_missing_predicate_to_the_other_check
    assert_empty run_check(Check, target(DoctorNoRulesPolicy))
  end

  private

  def target(policy_class, definition: DoctorConditionDefinition)
    doctor_target(
      resource_class: Blogging::Post,
      definition_class: definition,
      policy_class: policy_class
    )
  end
end

class DoctorHiddenDestroyDefinition < Plutonium::Resource::Definition
  action :destroy, record_action: true, condition: -> { current_user.admin? }
end

class DoctorNoRulesPolicy < Plutonium::Resource::Policy; end
