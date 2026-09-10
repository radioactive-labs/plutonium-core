# frozen_string_literal: true

require "test_helper"

# `display :x, as: :phlexi_render, with: ...` is deprecated in favour of the
# block form. The warning fires ONCE, where the display is declared, so the
# reported location is the app's definition file and an index page of N rows
# does not log N warnings (or, under `deprecation = :raise`, fail N times).
class Plutonium::Definition::PhlexiRenderDeprecationTest < ActiveSupport::TestCase
  def declare(as:, at: :class)
    if at == :class
      Class.new(Plutonium::Definition::Base) { display :priority, as:, with: ->(v, _a) { v } }
    else
      definition = Class.new(Plutonium::Definition::Base) {
        define_method(:customize_displays) { display :priority, as:, with: ->(v, _a) { v } }
      }.new
      definition.defined_displays
    end
  end

  test "as: :phlexi_render warns at declaration and names the block form for that field" do
    assert_deprecated(/display :priority do \|f\|/, Plutonium.deprecator) { declare(as: :phlexi_render) }
  end

  test "the :phlexi alias warns by the name the user wrote" do
    assert_deprecated(/as: :phlexi\b/, Plutonium.deprecator) { declare(as: :phlexi) }
  end

  test "an instance-level display in customize_displays warns too" do
    assert_deprecated(/display :priority do \|f\|/, Plutonium.deprecator) { declare(as: :phlexi_render, at: :instance) }
  end

  test "a display with any other as: does not warn" do
    assert_not_deprecated(Plutonium.deprecator) { declare(as: :badge) }
  end

  test "the declaration still lands in defined_displays" do
    definition = assert_deprecated(Plutonium.deprecator) { declare(as: :phlexi_render) }

    assert_equal :phlexi_render, definition.defined_displays[:priority][:options][:as]
  end

  test "rendering the component itself does not warn" do
    field = Plutonium::UI::Table::Base::Display.new(User.new(email: "a@b.c")).field(:email)

    assert_not_deprecated(Plutonium.deprecator) do
      field.component_for(:phlexi_render, with: ->(v, _a) { v })
    end
  end
end
