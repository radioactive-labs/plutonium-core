# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Dashboard::CardTest < ActiveSupport::TestCase
  class FakeViewContext; end

  class BrokenDashboard < Plutonium::Dashboard::Base
    card(:broken) do
      p { "half written" }
      raise ArgumentError, "bad query"
    end
  end

  class Subscriber
    attr_reader :reports

    def initialize = @reports = []

    def report(error, handled:, severity:, context:, source: nil)
      @reports << {error:, handled:, context:, source:}
    end
  end

  setup do
    @local = Rails.application.config.consider_all_requests_local
    @subscriber = Subscriber.new
    Rails.error.subscribe(@subscriber)
  end

  teardown do
    Rails.application.config.consider_all_requests_local = @local
    Rails.error.unsubscribe(@subscriber)
  end

  test "in local-request mode a failing card raises" do
    Rails.application.config.consider_all_requests_local = true

    assert_raises(ArgumentError) { render_card }
    assert_empty @subscriber.reports
  end

  test "outside local-request mode a failing card renders the notice in place of its body" do
    Rails.application.config.consider_all_requests_local = false

    html = render_card

    assert_match(/pu-dashboard-card-error/, html)
    assert_includes html, I18n.t("plutonium.dashboard.card_error")
    refute_includes html, "half written"
  end

  test "a failing card is reported to Rails.error with the dashboard and card" do
    Rails.application.config.consider_all_requests_local = false

    render_card

    assert_equal 1, @subscriber.reports.size
    report = @subscriber.reports.first
    assert_instance_of ArgumentError, report[:error]
    assert report[:handled]
    assert_equal "plutonium.dashboard", report[:source]
    assert_equal BrokenDashboard.name, report[:context][:dashboard]
    assert_equal "broken", report[:context][:card]
  end

  test "a failing card is logged, so it is visible with no error subscriber" do
    Rails.application.config.consider_all_requests_local = false
    log = StringIO.new
    logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)

    render_card

    assert_includes log.string, "#{BrokenDashboard.name}#broken"
    assert_includes log.string, "ArgumentError: bad query"
  ensure
    Rails.logger = logger
  end

  private

  def render_card
    dashboard = BrokenDashboard.new(FakeViewContext.new)
    Plutonium::UI::Dashboard::Custom.new(dashboard:, card: BrokenDashboard.find_card(:broken)).call
  end
end
