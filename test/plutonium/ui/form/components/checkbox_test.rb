# frozen_string_literal: true

require "test_helper"

# Regression guard for boolean form inputs. The checked state must reflect the
# stored value's truthiness using Rails' canonical boolean casting — values that
# arrive from JSON/text columns ("f", "FALSE", "off", 0, :false, ...) are all
# falsey to Rails and must render UNCHECKED. The fix lives upstream in
# phlexi-form (>= 0.14.3); this exercises every Plutonium render path so a
# regression (or a phlexi-form downgrade) is caught here.
class Plutonium::UI::Form::Components::CheckboxTest < ActiveSupport::TestCase
  # true-ish values -> checked
  TRUTHY = [true, 1, "1", "t", "true", "TRUE", "on"].freeze
  # Rails ActiveModel::Type::Boolean::FALSE_VALUES (+ nil / blank) -> unchecked
  FALSEY = [false, 0, "0", "f", "F", "false", "FALSE", "off", "OFF", :false, nil, ""].freeze # standard:disable Lint/BooleanSymbol

  # :boolean / :checkbox -> Phlexi checkbox; :toggle / :switch -> Plutonium Toggle
  %i[boolean checkbox toggle switch].each do |as|
    TRUTHY.each do |value|
      define_method(:"test_#{as}_checked_for_#{value.inspect}") do
        assert checked?(value, as), "as: #{as.inspect} should be CHECKED for #{value.inspect}"
      end
    end

    FALSEY.each do |value|
      define_method(:"test_#{as}_unchecked_for_#{value.inspect}") do
        refute checked?(value, as), "as: #{as.inspect} should be UNCHECKED for #{value.inspect}"
      end
    end
  end

  private

  def org
    @org ||= Organization.create!(name: "Org #{SecureRandom.hex(4)}")
  end

  # Render the given input via its real tag method and report whether the
  # checkbox is checked. `flag` returns a JSON/text-sourced value.
  def checked?(value, as)
    record = KitchenSink.new(name: "x", organization: org)
    record.define_singleton_method(:flag) { value }

    form = Plutonium::UI::Form::Resource.new(
      record,
      resource_fields: [:flag],
      resource_definition: Plutonium::Definition::Base.new,
      singular_resource: false
    )
    html = form.field(:flag).public_send(:"#{as}_tag").call
    # Only the checkbox input carries a bare `checked` attribute; the hidden
    # companion never does.
    html.match?(/\bchecked\b/)
  end
end
