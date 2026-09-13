# frozen_string_literal: true

require "test_helper"

# The metric card's number and change formatting, rendered standalone (no
# view context: the component only needs the card, the dashboard and I18n).
class Plutonium::UI::Dashboard::MetricTest < ActiveSupport::TestCase
  class FakeViewContext; end

  def render_metric(**options, &block)
    klass = Class.new(Plutonium::Dashboard::Base)
    klass.define_singleton_method(:name) { "MetricTestDashboard" }
    klass.metric(:sample, **options, &block)
    dashboard = klass.new(FakeViewContext.new)
    Plutonium::UI::Dashboard::Metric.new(dashboard:, card: klass.find_card(:sample)).call
  end

  test "renders the card chrome and a delimited integer" do
    html = render_metric(label: "Total orders", description: "All time") { 1_234_567 }

    assert_match(/pu-card/, html)
    assert_match(/pu-dashboard-card-title[^>]*>Total orders</, html)
    assert_match(/pu-dashboard-card-description[^>]*>All time</, html)
    assert_match(/pu-metric-value[^>]*>1,234,567</, html)
    refute_match(/pu-metric-change/, html)
  end

  test "formats currency, percentage and human numbers" do
    assert_match(/>\$1,200\.50</, render_metric(format: :currency) { 1200.5 })
    assert_match(/>€1,201</, render_metric(format: :currency, unit: "€", precision: 0) { 1200.5 })
    assert_match(/>12\.5%</, render_metric(format: :percentage) { 12.5 })
    assert_match(/>1\.23 Million</, render_metric(format: :human) { 1_234_000 })
    assert_match(/>~4\.1k</, render_metric(prefix: "~", suffix: "k") { 4.1 })
  end

  test "a proc format runs on the dashboard" do
    html = render_metric(format: ->(v) { "#{v} things" }) { 3 }
    assert_match(/>3 things</, html)
  end

  test "nil renders the empty marker" do
    assert_match(/pu-metric-value[^>]*>—</, render_metric { nil })
  end

  test "previous computes a percentage change and colours it by direction" do
    html = render_metric { {value: 1_240, previous: 1_000, change_label: "vs. last month"} }
    assert_match(/pu-metric-change-positive/, html)
    assert_match(/>\+24%</, html)
    assert_match(/pu-metric-change-label[^>]*>vs\. last month</, html)

    html = render_metric { {value: 900, previous: 1_000} }
    assert_match(/pu-metric-change-negative/, html)
    assert_match(/>-10%</, html)

    # A zero previous yields no percentage: nothing to show unless there is a caption.
    html = render_metric { {value: 1, previous: 0} }
    refute_match(/pu-metric-change/, html)

    html = render_metric { {value: 1, previous: 0, change_label: "vs. nothing"} }
    assert_match(/pu-metric-change-neutral/, html)
    refute_match(/font-medium/, html)
    assert_match(/vs\. nothing/, html)
  end

  test "positive: :down flips the colours" do
    assert_match(/pu-metric-change-negative/, render_metric(positive: :down) { {value: 5, previous: 4} })
    assert_match(/pu-metric-change-positive/, render_metric(positive: :down) { {value: 3, previous: 4} })
  end

  test "an explicit change is shown verbatim with its trend" do
    html = render_metric { {value: 5, change: "+140", trend: :up} }
    assert_match(/>\+140</, html)
    assert_match(/pu-metric-change-positive/, html)

    html = render_metric { {value: 5, change: 2.25} }
    assert_match(/>\+2\.3%</, html)
  end

  test "a card href links the title" do
    html = render_metric(href: "/orders") { 1 }
    assert_match(%r{<a href="/orders"[^>]*>Sample</a>}, html)
    assert_match(/pu-dashboard-card-link/, html)
  end

  test "a raising block renders a notice when requests are not local" do
    original = Rails.application.config.consider_all_requests_local
    Rails.application.config.consider_all_requests_local = false
    html = render_metric { raise "boom" }
    assert_match(/pu-dashboard-card-error/, html)
    assert_match(/could not be loaded/, html)
  ensure
    Rails.application.config.consider_all_requests_local = original
  end

  test "a raising block raises when requests are local" do
    original = Rails.application.config.consider_all_requests_local
    Rails.application.config.consider_all_requests_local = true
    assert_raises(RuntimeError) { render_metric { raise "boom" } }
  ensure
    Rails.application.config.consider_all_requests_local = original
  end
end
