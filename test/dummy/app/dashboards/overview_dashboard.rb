# The reference dashboard for the admin portal: one card of every kind, a
# conditional card, an inline (non-lazy) card and a refreshing card, so the
# integration suite can exercise the whole surface against live routes.
class OverviewDashboard < Plutonium::Dashboard::Base
  presents label: "Overview", description: "Everything at a glance", icon: Phlex::TablerIcons::ChartBar

  columns 4

  # Flipped by tests to exercise the `condition:` gate on the card endpoint.
  cattr_accessor :show_secret, default: false

  metric(:users, icon: Phlex::TablerIcons::Users, href: -> { resource_url_for(User, parent: nil) }) do
    authorized_resource_scope(User).count
  end

  metric(:organizations, format: :human, description: "Tenants on the platform") do
    {value: Organization.count, previous: previous_org_count, change_label: "vs. last month"}
  end

  metric(:conversion, format: :percentage, precision: 1, positive: :up, lazy: false) do
    {value: 12.5, change: 2.25, trend: :up}
  end

  metric(:churn, format: :percentage, positive: :down, refresh: 30) do
    {value: 1.2, change: "+0.4%", trend: :up}
  end

  metric(:secret, condition: -> { OverviewDashboard.show_secret }) { 42 }

  chart(:signups, type: :area, span: 2, description: "New organizations per day") do
    Organization.pluck(:created_at).map(&:to_date).tally.sort.to_h
  end

  chart(:by_kind, type: :donut, span: 2, height: "200px") do
    {"Users" => User.count, "Organizations" => Organization.count}
  end

  card(:welcome, span: :full) do
    p(class: "pu-dashboard-welcome") { "Signed in as #{current_user.email}" }
    p { greeting }
  end

  private

  def previous_org_count = 0

  def greeting = "Hello from the dashboard"
end
