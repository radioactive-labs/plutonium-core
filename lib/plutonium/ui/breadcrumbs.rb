module Plutonium
  module UI
    class Breadcrumbs < Plutonium::UI::Component::Base
      include Phlex::Rails::Helpers::ActionName
      include Phlex::Rails::Helpers::LinkTo

      # Shared styling for an inline breadcrumb label.
      LABEL_CLASSES = "ms-1 md:ms-2 flex items-center min-w-0 text-sm font-medium " \
                      "text-[var(--pu-text-muted)] transition-colors"
      LINK_CLASSES = "#{LABEL_CLASSES} hover:text-primary-600"

      # Styling for the same label when it is rendered as a row in the overflow
      # menu instead of inline. Full-row target, chevron-led to echo the
      # inline separators.
      MENU_LINK_CLASSES = "flex items-center gap-1.5 py-1.5 px-3 text-sm text-[var(--pu-text-muted)] " \
                          "hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] transition-colors"

      CHEVRON_INLINE_CLASSES = "rtl:rotate-180 block w-3 h-3 mx-1 shrink-0 text-[var(--pu-text-subtle)]"
      CHEVRON_MENU_CLASSES = "rtl:rotate-180 block w-3 h-3 shrink-0 text-[var(--pu-text-subtle)]"

      def view_template
        # `overflow-hidden` keeps the un-collapsed trail from spilling in the
        # instant before the controller's first reflow.
        nav(
          class: "flex min-w-0 py-3 mb-2 overflow-hidden",
          aria_label: "Breadcrumb",
          data: {controller: "breadcrumbs"}
        ) do
          ol(
            class: "flex flex-nowrap w-full min-w-0 items-center gap-1 md:gap-2",
            data: {breadcrumbs_target: "list"}
          ) do
            render_dashboard_link
            render_overflow_menu if middle_items.any?
            render_items
            render_trailing_separator
          end
        end
      end

      private

      # Every segment between the dashboard link and the trailing separator, as
      # a list of lambdas taking the CSS classes to render with. Collected up
      # front so each one can be rendered twice — inline, and again as a row in
      # the overflow menu that the controller reveals when it folds the inline
      # twin away.
      def breadcrumb_items
        @breadcrumb_items ||= [].tap do |items|
          collect_parent_breadcrumbs(items) if current_parent.present?
          collect_resource_breadcrumbs(items) if resource_record?
        end
      end

      # The segments eligible to be folded into the overflow menu. The last one
      # is never foldable — it is the deepest thing the trail knows about, which
      # is the record on new/edit pages but the resource index on show pages,
      # where the record itself is not part of the trail at all.
      def middle_items
        breadcrumb_items[0...-1]
      end

      def render_items
        last_index = breadcrumb_items.size - 1
        breadcrumb_items.each_with_index do |item, index|
          render_breadcrumb_item(foldable: index < last_index) do
            item.call(LINK_CLASSES)
          end
        end
      end

      def render_dashboard_link
        li(class: "flex items-center shrink-0") do
          a(
            href: root_path,
            class: "inline-flex items-center text-sm font-medium text-[var(--pu-text-muted)] hover:text-primary-600 transition-colors"
          ) do
            svg(
              class: "w-3 h-3 shrink-0 sm:me-2.5",
              aria_hidden: "true",
              xmlns: "http://www.w3.org/2000/svg",
              fill: "currentColor",
              viewbox: "0 0 20 20"
            ) do |s|
              s.path(
                d:
                  "m19.707 9.293-2-2-7-7a1 1 0 0 0-1.414 0l-7 7-2 2a1 1 0 0 0 1.414 1.414L2 10.414V18a2 2 0 0 0 2 2h3a1 1 0 0 0 1-1v-4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v4a1 1 0 0 0 1 1h3a2 2 0 0 0 2-2v-7.586l.293.293a1 1 0 0 0 1.414-1.414Z"
              )
            end
            span(class: "sr-only sm:not-sr-only") { plain "Dashboard" }
          end
        end
      end

      # Builds a segment renderer used in both places a segment can appear:
      # inline in the trail, and — with `leading:` — as a chevron-led row in
      # the overflow menu.
      def segment(label, url = nil)
        ->(classes, leading: false) {
          if url
            link_to(url, class: classes) do
              render_chevron_separator(CHEVRON_MENU_CLASSES) if leading
              span(class: "truncate min-w-0") { plain label }
            end
          else
            span(class: classes) do
              render_chevron_separator(CHEVRON_MENU_CLASSES) if leading
              span(class: "truncate min-w-0") { plain label }
            end
          end
        }
      end

      def collect_parent_breadcrumbs(items)
        # Parent Resource
        items << segment(
          resource_name_plural(current_parent.class),
          resource_url_for(current_parent.class, parent: nil)
        )

        # Parent Itself
        items << segment(
          display_name_of(current_parent),
          resource_url_for(current_parent, parent: nil)
        )
      end

      def collect_resource_breadcrumbs(items)
        # Ask the controller, not the top-level route registry: a has_one
        # association nests as a singular route regardless of how the child was
        # registered, and only the controller's config lookup is keyed by
        # "parent/association" and therefore knows that.
        if singular_resource_context?
          collect_singular_resource_breadcrumb(items)
        else
          collect_plural_resource_breadcrumbs(items)
        end
      end

      def collect_singular_resource_breadcrumb(items)
        # A singular resource has no index, so the only segment it can add is
        # itself — and on `show` the page title already names it, exactly as the
        # plural branch omits the record on its own show page.
        return unless resource_record!.persisted? && action_name != "show"

        items << segment(resource_name(resource_class), resource_url_for(resource_record!))
      end

      def collect_plural_resource_breadcrumbs(items)
        # Resource index link
        items << segment(
          nestable_resource_name_plural(resource_class),
          resource_url_for(resource_class)
        )

        # Record itself (for non-singular routes only)
        return unless resource_record!.persisted? && action_name != "show"

        items << segment(display_name_of(resource_record!), resource_url_for(resource_record!))
      end

      # Stands in for whatever the controller folded away, the way GitHub
      # collapses a long path. Starts hidden — it only earns its place once at
      # least one segment has actually been folded.
      def render_overflow_menu
        li(
          class: "hidden items-center shrink-0",
          data: {breadcrumbs_target: "overflow"}
        ) do
          render_chevron_separator
          div(
            class: "flex items-center",
            data: {
              controller: "resource-drop-down",
              resource_drop_down_placement_value: "bottom-start"
            }
          ) do
            render_overflow_trigger
            render_overflow_items
          end
        end
      end

      def render_overflow_trigger
        button(
          type: "button",
          aria: {label: "Show collapsed breadcrumbs", haspopup: "true", expanded: "false"},
          data: {resource_drop_down_target: "trigger"},
          class: "flex items-center justify-center ms-1 w-6 h-6 rounded-[var(--pu-radius-md)] " \
                 "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] transition-colors"
        ) do
          render Phlex::TablerIcons::Dots.new(class: "w-4 h-4")
        end
      end

      # One row per foldable segment. Each starts hidden; the controller reveals
      # exactly those whose inline twin it folded away.
      def render_overflow_items
        div(
          # No margin here — the dropdown controller already offsets the popper
          # off its trigger.
          class: "hidden z-50 py-1 min-w-40 max-w-[70vw] bg-[var(--pu-surface)] " \
                 "border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] overflow-hidden",
          style: "box-shadow: var(--pu-shadow-lg)",
          data: {resource_drop_down_target: "menu"}
        ) do
          ul(class: "list-none") do
            middle_items.each do |item|
              li(class: "hidden", data: {breadcrumbs_target: "menuItem"}) do
                item.call(MENU_LINK_CLASSES, leading: true)
              end
            end
          end
        end
      end

      def render_trailing_separator
        li(class: "flex items-center shrink-0") do
          render_chevron_separator
        end
      end

      # Segments are `shrink-0` so the controller measures natural widths and
      # can detect real overflow. The last one is additionally `min-w-0` so the
      # controller can drop its `shrink-0` and let it ellipsize once there is
      # nothing left to fold. Its `last` target must stay in lockstep with
      # `middle_items` — the controller pairs inline twins to menu rows by index.
      def render_breadcrumb_item(foldable: false, &)
        if foldable
          li(class: "flex items-center shrink-0", data: {breadcrumbs_target: "item"}) do
            render_chevron_separator
            yield
          end
        else
          li(class: "flex items-center shrink-0 min-w-0", data: {breadcrumbs_target: "last"}) do
            render_chevron_separator
            yield
          end
        end
      end

      def render_chevron_separator(classes = CHEVRON_INLINE_CLASSES)
        svg(
          class: classes,
          aria_hidden: "true",
          xmlns: "http://www.w3.org/2000/svg",
          fill: "none",
          viewbox: "0 0 6 10"
        ) do |s|
          s.path(
            stroke: "currentColor",
            stroke_linecap: "round",
            stroke_linejoin: "round",
            stroke_width: "2",
            d: "m1 9 4-4-4-4"
          )
        end
      end
    end
  end
end
