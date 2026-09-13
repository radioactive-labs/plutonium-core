# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Dashboard::CustomTest < ActiveSupport::TestCase
  class FakeViewContext; end

  class NotesDashboard < Plutonium::Dashboard::Base
    card(:notes) do
      ul { items.each { |item| li { item } } }
      p { shout("done") }
    end

    def items = %w[one two]

    private

    def shout(text) = text.upcase
  end

  test "the block renders Phlex markup and reaches the dashboard's methods" do
    dashboard = NotesDashboard.new(FakeViewContext.new)
    html = Plutonium::UI::Dashboard::Custom.new(dashboard:, card: NotesDashboard.find_card(:notes)).call

    assert_match(%r{<ul><li>one</li><li>two</li></ul>}, html)
    assert_match(%r{<p>DONE</p>}, html)
    assert_match(/pu-dashboard-card-title[^>]*>Notes</, html)
  end
end
