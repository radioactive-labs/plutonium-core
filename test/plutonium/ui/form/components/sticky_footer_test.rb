# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::StickyFooterTest < Minitest::Test
  def test_outer_div_has_fixed_bottom_positioning
    outer_class = capture_outer_div_class
    assert_includes outer_class, "fixed"
    assert_includes outer_class, "bottom-0"
    assert_includes outer_class, "left-0"
    assert_includes outer_class, "right-0"
  end

  def test_outer_div_offsets_for_icon_rail_on_desktop
    outer_class = capture_outer_div_class
    assert_includes outer_class, "lg:left-14"
  end

  def test_outer_div_has_surface_background_and_top_border
    outer_class = capture_outer_div_class
    assert_includes outer_class, "bg-[var(--pu-surface)]"
    assert_includes outer_class, "border-t"
    assert_includes outer_class, "border-[var(--pu-border)]"
  end

  def test_inner_div_centers_content_at_580px
    inner_class = capture_inner_div_class
    assert_includes inner_class, "max-w-[580px]"
    assert_includes inner_class, "mx-auto"
    assert_includes inner_class, "w-full"
  end

  def test_inner_div_has_flex_layout_for_action_buttons
    inner_class = capture_inner_div_class
    assert_includes inner_class, "flex"
    assert_includes inner_class, "items-center"
    assert_includes inner_class, "justify-end"
    assert_includes inner_class, "gap-2"
  end

  private

  def build_component
    Plutonium::UI::Form::Components::StickyFooter.allocate
  end

  # Captures the class attribute passed to the outermost div call in view_template.
  def capture_outer_div_class
    component = build_component
    outer_class = nil
    component.define_singleton_method(:div) do |**attrs, &_inner|
      outer_class ||= attrs[:class]
    end
    component.view_template
    outer_class.to_s
  end

  # Captures the class attribute passed to the inner div (centering wrapper).
  def capture_inner_div_class
    component = build_component
    call_count = 0
    inner_class = nil
    component.define_singleton_method(:div) do |**attrs, &inner|
      call_count += 1
      inner_class = attrs[:class] if call_count == 2
      inner&.call
    end
    component.view_template
    inner_class.to_s
  end
end
