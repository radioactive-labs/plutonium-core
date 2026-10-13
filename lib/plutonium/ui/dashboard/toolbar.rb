# frozen_string_literal: true

module Plutonium
  module UI
    module Dashboard
      # The row above the card grid: each filter as a segmented control of
      # links, so the choice is a plain URL that survives a reload and can be
      # shared, and the dashboard's links on the right.
      class Toolbar < Plutonium::UI::Component::Base
        def initialize(dashboard:)
          @dashboard = dashboard
        end

        def render?
          dashboard.class.filters.any? || links.any?
        end

        def view_template
          div(class: "pu-dashboard-toolbar mb-4 flex flex-wrap items-center justify-between gap-3") do
            div(class: "flex flex-wrap items-center gap-3") do
              dashboard.class.filters.each { |filter| render_filter(filter) }
            end
            div(class: "flex flex-wrap items-center gap-2") do
              links.each { |link, href| render_link(link, href) }
            end
          end
        end

        private

        attr_reader :dashboard

        # Visible links paired with their href. A link whose `href:` resolves
        # to nil (a proc that returns nothing for this user) is left out
        # rather than rendered as a dead button.
        def links
          @links ||= dashboard.visible_links.filter_map do |link|
            href = link.href_for(dashboard)
            [link, href] if href.present?
          end
        end

        def render_filter(filter)
          current = dashboard.filter_value(filter.key)
          nav(class: "pu-dashboard-filter inline-flex rounded-[var(--pu-radius-md)] border border-[var(--pu-border)] p-0.5",
            aria: {label: filter.label}, data: {dashboard_filter: filter.key}) do
            dashboard.filter_choices(filter).each do |value, label|
              selected = value == current
              a(
                href: filter_url(filter, value),
                class: tokens(
                  "rounded-[var(--pu-radius-sm)] px-3 py-1 text-sm transition-colors",
                  selected ? "bg-[var(--pu-surface-alt)] font-medium text-[var(--pu-text)]" : "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)]"
                ),
                aria: {current: selected ? "true" : nil}
              ) { Plutonium::Translation.resolve(label) }
            end
          end
        end

        def render_link(link, href)
          a(href:, class: "pu-btn pu-btn-sm pu-btn-outline", data: {dashboard_link: link.key}) do
            render link.icon.new(class: "size-4") if link.icon
            span { link.label }
          end
        end

        # The page with this filter set and the rest of the query string kept.
        def filter_url(filter, value)
          query = dashboard.request.query_parameters.merge(filter.key.to_s => value)
          "#{dashboard.request.path}?#{query.to_query}"
        end
      end
    end
  end
end
