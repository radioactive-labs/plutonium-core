# frozen_string_literal: true

require "test_helper"

class Plutonium::Dashboard::RegisterTest < Minitest::Test
  class OneDashboard < Plutonium::Dashboard::Base; end

  class TwoDashboard < Plutonium::Dashboard::Base; end

  def test_registers_in_order_without_duplicates
    register = Plutonium::Dashboard::Register.new
    assert register.empty?

    register.register(TwoDashboard)
    register.register(OneDashboard)
    register.register(TwoDashboard)

    assert_equal [TwoDashboard, OneDashboard], register.dashboards
    assert register.registered?(OneDashboard)

    register.clear
    assert register.empty?
  end

  def test_rejects_non_dashboards
    register = Plutonium::Dashboard::Register.new
    assert_raises(ArgumentError) { register.register(String) }
    assert_raises(ArgumentError) { register.register(Plutonium::Dashboard::Base) }
  end
end
