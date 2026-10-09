# frozen_string_literal: true

require "test_helper"

# Table cells render through this theme, not the show page's. Keys missing here
# resolve to nil, so a cell silently loses styling the show page has.
class Plutonium::UI::Table::DisplayThemeTest < ActiveSupport::TestCase
  def theme = Plutonium::UI::Table::DisplayTheme.instance

  test "markdown cells get prose styling" do
    assert_includes theme.resolve_theme(:markdown).to_s, "format"
  end

  test "currency cells align digits" do
    assert_includes theme.resolve_theme(:currency).to_s, "tabular-nums"
  end
end
