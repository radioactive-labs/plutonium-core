# frozen_string_literal: true

module Plutonium
  module UI
    # Connected split "Export" control for the index toolbar (sits beside
    # the Filter button and shares its `pu-btn-outline pu-btn-sm` styling).
    #
    # The primary button exports the current view (selected scope + filters
    # + search). The caret opens a menu with "Export all", which exports the
    # entire authorized scope.
    #
    # Both links carry `target="_blank"`, which opens the streamed download
    # in a new tab and bypasses Turbo (Turbo ignores links with a `target`).
    #
    # The two halves are joined into one control by flattening their shared
    # inner corners via inline styles (`rounded-*-none` utilities aren't in
    # the packaged stylesheet), so it reads as a single button rather than
    # two pills.
    class ExportButton < Plutonium::UI::Component::Base
      # Inline corner/border tweaks that join the two halves seamlessly.
      PRIMARY_STYLE = "border-top-right-radius:0;border-bottom-right-radius:0"
      CARET_STYLE = "border-top-left-radius:0;border-bottom-left-radius:0;border-left-width:0;padding-left:0.375rem;padding-right:0.375rem"

      def initialize(scoped_url:, all_url:)
        @scoped_url = scoped_url
        @all_url = all_url
      end

      def view_template
        div(class: "relative inline-flex", data: {controller: "resource-drop-down"}) do
          render_primary
          render_caret
          render_menu
        end
      end

      private

      def render_primary
        a(
          href: @scoped_url,
          target: "_blank",
          rel: "noopener",
          class: "pu-btn pu-btn-outline pu-btn-sm",
          style: PRIMARY_STYLE
        ) do
          render Phlex::TablerIcons::Download.new(class: "w-4 h-4 shrink-0")
          span { "Export" }
        end
      end

      def render_caret
        button(
          type: "button",
          class: "pu-btn pu-btn-outline pu-btn-sm",
          style: CARET_STYLE,
          aria: {expanded: "false", haspopup: "menu", label: "More export options"},
          data: {resource_drop_down_target: "trigger"}
        ) do
          render Phlex::TablerIcons::ChevronDown.new(class: "w-4 h-4")
        end
      end

      def render_menu
        div(
          class: "hidden absolute right-0 top-full z-50 mt-1 w-48 origin-top-right bg-[var(--pu-surface)] " \
                 "border border-[var(--pu-border)] rounded-[var(--pu-radius-lg)] overflow-hidden",
          style: "box-shadow: var(--pu-shadow-lg)",
          data: {resource_drop_down_target: "menu"}
        ) do
          div(class: "py-1") do
            a(
              href: @all_url,
              target: "_blank",
              rel: "noopener",
              class: "flex items-center gap-2 px-4 py-2 text-sm text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] transition-colors"
            ) do
              render Phlex::TablerIcons::Download.new(class: "w-4 h-4")
              span { "Export all" }
            end
          end
        end
      end
    end
  end
end
