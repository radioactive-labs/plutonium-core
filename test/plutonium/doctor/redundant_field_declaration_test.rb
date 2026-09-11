# frozen_string_literal: true

require "test_helper"

class DoctorDeclarationsDefinition < Plutonium::Resource::Definition
  # Dead: repeats what the model already said.
  field :title
  display :body
  column :created_at

  # Alive: each overrides something.
  field :summary, as: :markdown
  display :published_at, wrapper: {class: "col-span-2"}
  column :status, condition: -> { true }
  field :byline do
    "written by someone"
  end

  # Never checked — defined_inputs.keys is a source list for nested inputs,
  # structured inputs and wizard steps, so a bare input can be load-bearing.
  input :slug
end

class DoctorDeclarationsPolicy < Plutonium::Resource::Policy
  def permitted_attributes_for_create = %i[title]

  def permitted_attributes_for_read = %i[title]
end

class Plutonium::Doctor::RedundantFieldDeclarationTest < Minitest::Test
  include DoctorHelpers

  Check = Plutonium::Doctor::Checks::RedundantFieldDeclaration

  def test_reports_every_bare_declaration
    subjects = findings.map(&:subject)

    assert_includes subjects, "DoctorDeclarationsDefinition#field:title"
    assert_includes subjects, "DoctorDeclarationsDefinition#display:body"
    assert_includes subjects, "DoctorDeclarationsDefinition#column:created_at"
    assert_equal 3, findings.size
  end

  def test_leaves_a_declaration_carrying_options_alone
    subjects = findings.map(&:subject)

    refute_includes subjects, "DoctorDeclarationsDefinition#field:summary"
    refute_includes subjects, "DoctorDeclarationsDefinition#display:published_at"
    refute_includes subjects, "DoctorDeclarationsDefinition#column:status"
  end

  def test_leaves_a_declaration_carrying_a_block_alone
    refute_includes findings.map(&:subject), "DoctorDeclarationsDefinition#field:byline"
  end

  # defined_inputs.keys IS the field set for nested resource fields, structured
  # inputs and wizard steps, so a bare input is not dead code there. Warning on
  # it would teach people to ignore the doctor.
  def test_never_reports_an_input
    assert_empty findings.select { |f| f.subject.include?("input:") }
  end

  def test_is_a_warning_not_an_error
    assert findings.all?(&:warning?)
  end

  def test_points_at_the_policy_for_making_a_field_appear
    finding = findings.find { |f| f.subject.end_with?("field:title") }

    assert_match(/permitted_attributes_for_\*/, finding.details)
    assert_match(/can be deleted/, finding.message)
  end

  private

  def findings
    @findings ||= run_check(Check, doctor_target(
      resource_class: Blogging::Post,
      definition_class: DoctorDeclarationsDefinition,
      policy_class: DoctorDeclarationsPolicy
    ))
  end
end
