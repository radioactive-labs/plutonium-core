# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Display::Components::BadgeTest < ActiveSupport::TestCase
  Badge = Plutonium::UI::Display::Components::Badge

  # ---------------------------------------------------------------------------
  # variant_for — semantic dictionary
  # ---------------------------------------------------------------------------

  test "maps positive statuses to success" do
    %w[active approved completed paid published verified].each do |status|
      assert_equal :success, Badge.variant_for(status), "expected #{status} → :success"
    end
  end

  test "maps in-progress statuses to warning" do
    %w[pending processing in_progress draft scheduled].each do |status|
      assert_equal :warning, Badge.variant_for(status), "expected #{status} → :warning"
    end
  end

  test "maps terminal/negative statuses to danger" do
    %w[failed rejected cancelled expired banned refunded].each do |status|
      assert_equal :danger, Badge.variant_for(status), "expected #{status} → :danger"
    end
  end

  test "is case-insensitive" do
    assert_equal :success, Badge.variant_for("ACTIVE")
    assert_equal :danger, Badge.variant_for("Failed")
  end

  test "accepts symbol values" do
    assert_equal :success, Badge.variant_for(:active)
  end

  test "unknown values get a deterministic decorative variant" do
    first = Badge.variant_for("wibble")
    assert_includes Badge::DECORATIVE, first
    assert_equal first, Badge.variant_for("wibble"), "must be stable for the same value"
  end

  test "different unknown values can get different variants" do
    variants = %w[alpha bravo charlie delta echo foxtrot].map { |v| Badge.variant_for(v) }
    assert variants.uniq.size > 1, "expected the decorative palette to spread values"
  end

  test "nil falls back to neutral" do
    assert_equal :neutral, Badge.variant_for(nil)
  end

  # ---------------------------------------------------------------------------
  # variant_for — per-field overrides
  # ---------------------------------------------------------------------------

  test "override by symbol key wins over the dictionary" do
    assert_equal :neutral, Badge.variant_for("active", colors: {active: :neutral})
  end

  test "override by string value key works" do
    assert_equal :accent, Badge.variant_for("vip", colors: {"vip" => :accent})
  end

  test "override matching the raw value object works" do
    assert_equal :info, Badge.variant_for(:queued, colors: {queued: :info})
  end

  test "invalid override variant is ignored in favor of the dictionary" do
    assert_equal :success, Badge.variant_for("active", colors: {active: :bogus})
  end

  test "override does not affect unrelated values" do
    assert_equal :danger, Badge.variant_for("failed", colors: {active: :neutral})
  end

  # ---------------------------------------------------------------------------
  # humanize
  # ---------------------------------------------------------------------------

  test "humanizes the label for display" do
    assert_equal "In progress", Badge.humanize("in_progress")
    assert_equal "Active", Badge.humanize(:active)
  end

  # ---------------------------------------------------------------------------
  # normalize_value — keep the raw value for color mapping
  # ---------------------------------------------------------------------------

  test "normalize_value preserves the raw value" do
    component = Badge.allocate
    assert_equal :active, component.send(:normalize_value, :active)
  end
end
