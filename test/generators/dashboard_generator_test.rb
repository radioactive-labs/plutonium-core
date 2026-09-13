# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/dashboard/dashboard_generator"

# Runs against a throwaway destination_root: it writes a dashboard file and
# edits a routes file, neither of which the rest of the suite should see.
class DashboardGeneratorTest < Rails::Generators::TestCase
  tests Pu::DashboardGenerator
  destination File.expand_path("../../tmp/pu_dashboard", __dir__)
  setup :prepare_destination

  setup do
    FileUtils.mkdir_p(File.join(destination_root, "packages/admin_portal/config"))
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "packages/admin_portal/config/routes.rb"), <<~RUBY)
      AdminPortal::Engine.routes.draw do
        root to: "dashboard#index"

        # register resources above.
      end
    RUBY
    File.write(File.join(destination_root, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
        root "home#index"
      end
    RUBY
  end

  test "writes a portal dashboard and registers it at its slug" do
    run_generator %w[Sales --dest=admin_portal]

    assert_file "packages/admin_portal/app/dashboards/admin_portal/sales_dashboard.rb" do |content|
      assert_match(/module AdminPortal\n  class SalesDashboard < Plutonium::Dashboard::Base/, content)
      assert_match(/presents label: "Sales"/, content)
    end
    assert_file "packages/admin_portal/config/routes.rb" do |content|
      assert_match(/^  register_dashboard AdminPortal::SalesDashboard, at: "sales"\n\n  # register resources above\./, content)
      assert_match(/root to: "dashboard#index"/, content)
    end
  end

  test "a root mount replaces the generated root line" do
    run_generator %w[Home --dest=admin_portal --at=/]

    assert_file "packages/admin_portal/config/routes.rb" do |content|
      assert_match(/^  register_dashboard AdminPortal::HomeDashboard, at: "\/"/, content)
      refute_match(/root to: "dashboard#index"/, content)
    end
  end

  test "is idempotent" do
    run_generator %w[Sales --dest=admin_portal]
    run_generator %w[Sales --dest=admin_portal]

    assert_file "packages/admin_portal/config/routes.rb" do |content|
      assert_equal 1, content.scan("register_dashboard AdminPortal::SalesDashboard").size
    end
  end

  test "a main-app dashboard lives under app/dashboards" do
    run_generator %w[Reporting --dest=main_app --at=reports]

    assert_file "app/dashboards/reporting_dashboard.rb" do |content|
      assert_match(/\Aclass ReportingDashboard < Plutonium::Dashboard::Base/, content)
    end
    assert_file "config/routes.rb" do |content|
      assert_match(/^  register_dashboard ::ReportingDashboard, at: "reports"/, content)
    end
  end
end
