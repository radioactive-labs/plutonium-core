# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::PageWidthsTest < Minitest::Test
  def definition(&block)
    Class.new(Plutonium::Definition::Base, &block)
  end

  def with_default(width)
    previous = Plutonium.configuration.default_page_width
    Plutonium.configuration.default_page_width = width
    yield
  ensure
    Plutonium.configuration.default_page_width = previous
  end

  def test_falls_back_to_the_global_default
    with_default(:md) do
      d = definition {}.new
      assert_equal :md, d.resolved_form_width
      assert_equal :md, d.resolved_display_width
    end
  end

  def test_page_width_sets_both_surfaces
    with_default(:md) do
      d = definition { page_width :lg }.new
      assert_equal :lg, d.resolved_form_width
      assert_equal :lg, d.resolved_display_width
    end
  end

  def test_surface_specific_width_wins_over_page_width
    with_default(:md) do
      d = definition {
        page_width :lg
        display_width :full
      }.new
      assert_equal :lg, d.resolved_form_width, "form keeps page_width"
      assert_equal :full, d.resolved_display_width, "display takes its own"
    end
  end

  def test_form_width_alone_leaves_display_on_the_default
    with_default(:md) do
      d = definition { form_width :sm }.new
      assert_equal :sm, d.resolved_form_width
      assert_equal :md, d.resolved_display_width
    end
  end

  # `:full` is a legitimate choice, not "unset" — resolution must not treat it
  # as missing and fall through to the default.
  def test_explicit_full_is_honoured_over_the_default
    with_default(:md) do
      d = definition { page_width :full }.new
      assert_equal :full, d.resolved_form_width
      assert_nil d.form_width_classes, ":full must add no width classes at all"
    end
  end

  def test_widths_inherit_to_subclasses
    parent = definition { page_width :lg }
    assert_equal :lg, Class.new(parent).new.resolved_form_width
  end

  def test_subclass_can_override_the_parent_width
    parent = definition { page_width :lg }
    child = Class.new(parent)
    child.page_width :sm
    assert_equal :sm, child.new.resolved_form_width
    assert_equal :lg, parent.new.resolved_form_width, "parent must be untouched"
  end

  def test_unknown_width_raises_at_declaration
    error = assert_raises(ArgumentError) { definition { page_width :enormous } }
    assert_match(/page width must be one of/, error.message)
  end

  def test_unknown_surface_width_raises_too
    assert_raises(ArgumentError) { definition { form_width :nope } }
    assert_raises(ArgumentError) { definition { display_width :nope } }
  end

  def test_classes_include_a_max_width_and_centring
    with_default(:md) do
      classes = definition {}.new.form_width_classes
      assert_includes classes, "max-w-4xl"
      assert_includes classes, "mx-auto"
    end
  end

  def test_reader_form_returns_the_configured_token
    klass = definition { page_width :xl }
    assert_equal :xl, klass.page_width
  end
end
