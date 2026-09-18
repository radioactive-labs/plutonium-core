# frozen_string_literal: true

require "test_helper"

# Dashboard and card titles resolve by convention, layered per portal like
# every other derived label.
class Plutonium::Dashboard::TranslationTest < ActiveSupport::TestCase
  include I18nTestHelper

  class ReportsDashboard < Plutonium::Dashboard::Base
    metric(:orders) { 1 }
    metric(:named, label: "Explicit", description: "Given") { 1 }
  end

  def teardown
    Plutonium::Translation::Current.reset
    I18n.backend.reload!
  end

  test "falls back to the class and key when nothing is defined" do
    assert_equal "Reports", ReportsDashboard.label
    assert_nil ReportsDashboard.description
    assert_equal "Orders", ReportsDashboard.find_card(:orders).label
    assert_nil ReportsDashboard.find_card(:orders).description
  end

  test "resolves plutonium.dashboards.<dashboard>.* and .cards.<card>.*" do
    store_translations(plutonium: {dashboards: {
      "plutonium/dashboard/translation_test/reports" => {
        label: "Berichte", description: "Alles auf einen Blick",
        cards: {orders: {label: "Bestellungen", description: "Diesen Monat"}}
      }
    }})

    assert_equal "Berichte", ReportsDashboard.label
    assert_equal "Alles auf einen Blick", ReportsDashboard.description
    assert_equal "Bestellungen", ReportsDashboard.find_card(:orders).label
    assert_equal "Diesen Monat", ReportsDashboard.find_card(:orders).description
  end

  test "a portal-specific key wins over the global one" do
    store_translations(plutonium: {
      dashboards: {"plutonium/dashboard/translation_test/reports" => {label: "Global"}},
      portals: {admin_portal: {dashboards: {"plutonium/dashboard/translation_test/reports" => {label: "Admin"}}}}
    })

    assert_equal "Global", ReportsDashboard.label
    Plutonium::Translation::Current.portal = AdminPortal
    assert_equal "Admin", ReportsDashboard.label
  end

  test "an explicit label or description wins over the convention" do
    store_translations(plutonium: {dashboards: {
      "plutonium/dashboard/translation_test/reports" => {cards: {named: {label: "Convention"}}}
    }})

    assert_equal "Explicit", ReportsDashboard.find_card(:named).label
    assert_equal "Given", ReportsDashboard.find_card(:named).description
  end
end
