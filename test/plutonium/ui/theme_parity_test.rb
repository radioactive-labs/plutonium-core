# frozen_string_literal: true

require "test_helper"

# Each tag hands `create_component` a theme key. A key missing from a theme
# resolves to nil, so the component silently renders unstyled on that surface
# (the table once lost the color swatch this way). Display tags render on the
# show page AND in table cells, which use separate themes.
class Plutonium::UI::ThemeParityTest < ActiveSupport::TestCase
  THEME_KEY = /create_component\([^,]+,\s*:(\w+)/

  def theme_keys(path)
    File.read(File.expand_path("../../../lib/plutonium/ui/#{path}", __dir__)).scan(THEME_KEY).flatten.map(&:to_sym).uniq
  end

  def assert_themed(keys, theme)
    missing = keys.reject { |key| theme.theme.key?(key) }
    assert_empty missing, "#{theme} has no entry for #{missing.inspect}"
  end

  test "form tags are themed" do
    assert_themed theme_keys("form/base.rb"), Plutonium::UI::Form::Theme
  end

  test "display tags are themed on the show page" do
    assert_themed theme_keys("display/base.rb"), Plutonium::UI::Display::Theme
  end

  test "display tags are themed in table cells" do
    assert_themed theme_keys("display/base.rb") + theme_keys("table/base.rb"), Plutonium::UI::Table::DisplayTheme
  end
end
