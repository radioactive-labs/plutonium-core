# frozen_string_literal: true

require "test_helper"

class DoctorBareDefinition < Plutonium::Resource::Definition; end

# Declares nothing — every permitted-attributes call falls through to
# autodetection.
class DoctorSilentPolicy < Plutonium::Resource::Policy; end

class DoctorReadOnlyPolicy < Plutonium::Resource::Policy
  def permitted_attributes_for_read = %i[title]
end

class DoctorCompletePolicy < Plutonium::Resource::Policy
  def permitted_attributes_for_create = %i[title]

  def permitted_attributes_for_read = %i[title]
end

# Covers every read-side entry point without ever defining the base underneath
# them, so nothing can reach the autodetecting method.
class DoctorEntryPointPolicy < Plutonium::Resource::Policy
  def permitted_attributes_for_create = %i[title]

  def permitted_attributes_for_index = %i[title]

  def permitted_attributes_for_show = %i[title]
end

class Plutonium::Doctor::AutodetectedPermittedAttributesTest < Minitest::Test
  include DoctorHelpers

  Check = Plutonium::Doctor::Checks::AutodetectedPermittedAttributes

  def test_reports_both_bases_when_the_policy_declares_nothing
    findings = run_check(Check, target(DoctorSilentPolicy))

    assert_equal 2, findings.size
    assert_equal(
      ["Blogging::Post#permitted_attributes_for_create", "Blogging::Post#permitted_attributes_for_read"],
      findings.map(&:subject).sort
    )
    assert findings.all?(&:error?)
  end

  def test_reports_only_the_base_that_is_still_missing
    finding = run_check(Check, target(DoctorReadOnlyPolicy)).sole

    assert_equal "Blogging::Post#permitted_attributes_for_create", finding.subject
  end

  def test_says_nothing_when_both_bases_are_declared
    assert_empty run_check(Check, target(DoctorCompletePolicy))
  end

  def test_says_nothing_when_every_entry_point_answers_for_itself
    # permitted_attributes_for_read is undefined, but nothing reaches it:
    # index and show answer directly, and export delegates to index.
    assert_empty run_check(Check, target(DoctorEntryPointPolicy))
  end

  def test_names_the_entry_points_that_reach_the_missing_base
    finding = run_check(Check, target(DoctorReadOnlyPolicy)).sole

    assert_match(/permitted_attributes_for_new/, finding.details)
    assert_match(/permitted_attributes_for_create/, finding.details)
    assert_match(/raise outside development/, finding.message)
  end

  def test_suggests_real_columns_so_the_fix_is_copy_pasteable
    finding = run_check(Check, target(DoctorReadOnlyPolicy)).sole
    suggested = finding.details[/%i\[([^\]]*)\]/, 1].to_s.split

    refute_empty suggested, "the suggested override should name real fields, not an empty list"
    assert (suggested - Blogging::Post.resource_field_names.map(&:to_s)).empty?,
      "suggested #{suggested.inspect} should all be fields of Blogging::Post"
    refute_includes suggested, Blogging::Post.primary_key
    refute_includes suggested, "created_at"
  end

  # The delegation map in the check is hardcoded, because the delegation lives
  # in method bodies and cannot be read off the class. This locks it to the real
  # Plutonium::Resource::Policy: if a default ever stops delegating where the map
  # says it does, this fails rather than the check quietly going blind.
  def test_delegation_map_matches_the_base_policy
    Check::ENTRY_POINTS.each do |entry|
      assert_equal probed_base(entry), resolved_base(entry),
        "#{entry} reaches a different base than Checks::AutodetectedPermittedAttributes::DELEGATIONS claims"
    end
  end

  private

  # Where an entry point ACTUALLY lands, by making autodetection announce itself.
  def probed_base(entry)
    probe = Class.new(Plutonium::Resource::Policy) do
      define_method(:autodetect_permitted_fields) { |name| throw :autodetected, name }
    end.new(record: Blogging::Post, user: Object.new, entity_scope: nil)

    catch(:autodetected) do
      probe.public_send(entry)
      nil
    end
  end

  # Where the check's map says it lands, with no application override anywhere.
  def resolved_base(entry)
    current = entry
    current = Check::DELEGATIONS[current] until current.nil? || Check::BASES.include?(current)
    current
  end

  def target(policy_class)
    doctor_target(
      resource_class: Blogging::Post,
      definition_class: DoctorBareDefinition,
      policy_class: policy_class
    )
  end
end
