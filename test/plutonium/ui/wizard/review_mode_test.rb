# frozen_string_literal: true

require "test_helper"

# Unit-tests the review body composition (which pieces render) in isolation —
# pure logic over the runner state, no Phlex render. The actual HTML of each
# piece is covered by the integration flow test.
class Plutonium::UI::Wizard::ReviewModeTest < ActiveSupport::TestCase
  # A minimal runner double: the predicates only read these.
  FakeRunner = Struct.new(:incomplete_visible_steps, :current_step)

  def review_for(incomplete:, summary:, block:)
    step = Plutonium::Wizard::ReviewStep.new(summary:, block:)
    runner = FakeRunner.new(incomplete, step)
    Plutonium::UI::Wizard::Review.new(runner:, step_url: ->(k) { "/#{k}" })
  end

  # The pieces that would render, in render order.
  def pieces(**)
    r = review_for(**)
    %i[outstanding summary custom ready].select { |p| r.send(:"show_#{p}?") }
  end

  # --- incomplete -----------------------------------------------------------

  def test_incomplete_summary_on_shows_outstanding_and_summary
    # custom block present but NOT shown — custom only appears once complete.
    assert_equal %i[outstanding summary], pieces(incomplete: [:a], summary: true, block: -> {})
  end

  def test_incomplete_summary_off_shows_only_outstanding
    assert_equal %i[outstanding], pieces(incomplete: [:a], summary: false, block: nil)
  end

  # --- complete -------------------------------------------------------------

  def test_complete_summary_on_no_block_shows_summary
    assert_equal %i[summary], pieces(incomplete: [], summary: true, block: nil)
  end

  def test_complete_summary_on_with_block_shows_summary_then_custom
    # The block is ADDITIVE below the summary, not a replacement.
    assert_equal %i[summary custom], pieces(incomplete: [], summary: true, block: -> {})
  end

  def test_complete_summary_off_with_block_shows_only_custom
    # Summary off → the custom block REPLACES the summary.
    assert_equal %i[custom], pieces(incomplete: [], summary: false, block: -> {})
  end

  def test_complete_summary_off_no_block_shows_ready
    assert_equal %i[ready], pieces(incomplete: [], summary: false, block: nil)
  end
end
