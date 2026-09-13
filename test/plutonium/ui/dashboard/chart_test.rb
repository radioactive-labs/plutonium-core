# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Dashboard::ChartTest < ActiveSupport::TestCase
  class FakeViewContext; end

  def render_chart(**options, &block)
    klass = Class.new(Plutonium::Dashboard::Base)
    klass.define_singleton_method(:name) { "ChartTestDashboard" }
    klass.chart(:sample, **options, &block)
    dashboard = klass.new(FakeViewContext.new)
    Plutonium::UI::Dashboard::Chart.new(dashboard:, card: klass.find_card(:sample), script_url: "/assets/charts.js").call
  end

  test "serialises the data and options onto the chart controller" do
    html = render_chart(type: :column, height: "300px", stacked: true) { {"Mon" => 1, "Tue" => 2} }

    assert_match(/data-controller="chart"/, html)
    assert_match(/data-chart-type-value="ColumnChart"/, html)
    assert_match(/data-chart-data-value="\{&quot;Mon&quot;:1,&quot;Tue&quot;:2\}"/, html)
    assert_match(/data-chart-options-value="\{&quot;stacked&quot;:true\}"/, html)
    assert_match(%r{data-chart-script-value="/assets/charts.js"}, html)
    assert_match(/style="height: 300px;"/, html)
  end

  test "donut is a pie chart with the donut flag" do
    html = render_chart(type: :donut) { [] }
    assert_match(/data-chart-type-value="PieChart"/, html)
    assert_match(/&quot;donut&quot;:true/, html)
  end

  test "date keys serialise as ISO strings" do
    html = render_chart { {Date.new(2026, 1, 2) => 3} }
    assert_match(/&quot;2026-01-02&quot;:3/, html)
  end
end
