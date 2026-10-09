# frozen_string_literal: true

require "test_helper"

# Badge, Boolean and Color called `tag(**attributes, class: ...)`, which
# replaced the themed class and any `class:` passed via `display ..., class:`.
class Plutonium::UI::Display::Components::ValueAttributesTest < ActiveSupport::TestCase
  def render_tag(tag, key, record: KitchenSink.new, **attributes)
    Plutonium::UI::Display::Base.new(record).field(key).public_send(:"#{tag}_tag", **attributes).call
  end

  test "a badge keeps a caller's class" do
    html = render_tag(:badge, :status, class: "ml-2")

    assert_includes html, "ml-2"
    assert_includes html, "pu-badge-success"
  end

  test "a boolean pill keeps a caller's class" do
    html = render_tag(:boolean, :active, class: "ml-2")

    assert_includes html, "ml-2"
    assert_includes html, "pu-badge-success"
  end

  test "a color swatch keeps a caller's class" do
    assert_includes render_tag(:color, :favorite_color, class: "ml-2"), "ml-2"
  end

  test "the color swatch uses the color_indicator theme key" do
    indicator = Plutonium::UI::Display::Theme.instance.resolve_theme(:color_indicator)

    assert_includes render_tag(:color, :favorite_color), indicator
  end

  # The value was interpolated into `style:`, so a stored string could inject
  # arbitrary CSS (e.g. a background-image beacon).
  test "a non-color value never reaches the swatch style" do
    record = KitchenSink.new(favorite_color: "red; background-image: url(https://evil.test/x)")
    html = render_tag(:color, :favorite_color, record:)

    refute_match(/style="[^"]*evil/, html)
  end

  test "a hex color reaches the swatch style" do
    assert_includes render_tag(:color, :favorite_color), "background-color: #3b82f6"
  end
end
