# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # Modern index toolbar combining view switcher, filter/group controls,
        # inline search, and column config / overflow icon buttons into a single
        # tight strip rendered above the table when shell == :modern.
        class Toolbar < Plutonium::UI::Component::Base
          def initialize(query:, search_url:, search_param: :q, search_value: nil, views: [:table], current_view: :table, view_cookie_name: nil, view_cookie_path: "/")
            @query = query
            @search_url = search_url
            @search_param = search_param
            @search_value = search_value
            @views = views
            @current_view = current_view
            @view_cookie_name = view_cookie_name
            @view_cookie_path = view_cookie_path
          end

          def render?
            @views.size > 1 || has_filters? || has_search?
          end

          def view_template
            div(class: "flex items-center gap-2 px-4 py-2 border-b border-[var(--pu-border)] bg-[var(--pu-surface-alt)]") do
              switcher = ViewSwitcher.new(views: @views, current: @current_view, cookie_name: @view_cookie_name, cookie_path: @view_cookie_path)
              render switcher
              render_divider if switcher.render?
              render_filter_button
              div(class: "flex-1")
              render_search if has_search?
            end
          end

          private

          def has_filters?
            @query && @query.filter_definitions.present?
          end

          def has_search?
            @query && @query.search_filter.present?
          end

          def active_filter_count
            @query ? @query.active_filter_descriptions.size : 0
          end

          def render_divider
            div(class: "w-px h-5 bg-[var(--pu-border)]")
          end

          def render_filter_button
            return unless has_filters?

            count = active_filter_count
            button(
              type: "button",
              class: "pu-btn pu-btn-outline pu-btn-sm",
              data: {action: "click->filter-panel#toggle"}
            ) do
              render Phlex::TablerIcons::AdjustmentsHorizontal.new(class: "w-4 h-4 shrink-0")
              span { "Filter" }
              if count > 0
                span(class: "ml-1 inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 " \
                            "rounded-full bg-primary-600 text-white text-[10px] font-semibold leading-none") do
                  plain count.to_s
                end
              end
            end
          end

          def render_search
            form(method: :get, action: @search_url) do
              div(class: "relative") do
                div(class: "absolute inset-y-0 left-0 flex items-center pl-2 pointer-events-none") do
                  render Phlex::TablerIcons::Search.new(class: "w-4 h-4 text-[var(--pu-text-muted)]")
                end
                input(
                  id: "pu-toolbar-search",
                  type: "search",
                  name: "#{@search_param}[search]",
                  value: @search_value,
                  placeholder: "Search...",
                  class: "pu-input pu-input-toolbar pu-input-icon-left w-[220px]",
                  # turbo-permanent + a stable id keep the DOM node
                  # across Turbo morphs so focus / caret / IME state
                  # survive the search-as-you-type submit cycle.
                  data: {
                    controller: "autosubmit",
                    action: "input->autosubmit#submit search->autosubmit#submit",
                    turbo_permanent: true
                  }
                )
              end
            end
          end
        end
      end
    end
  end
end
