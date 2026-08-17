# frozen_string_literal: true

module Plutonium
  module UI
    module Component
      # Shared chrome for a declared layout section — a card with a header row
      # (accent bar, heading, optional description, optional collapse caret)
      # over a body that holds the fields. Subclassed (not copied) by both
      # {Plutonium::UI::Form::Components::Section} and
      # {Plutonium::UI::Display::Components::Section} so a form section and a
      # show-page section always read the same; the only difference between the
      # two is which grid class the caller passes in.
      #
      # Each section is its OWN card rather than a band inside one shared card.
      # The card boundary does the grouping — no amount of heading typography
      # separates two field groups as unambiguously as an actual edge does, and
      # the header row then only has to name the group rather than carry the
      # whole structural signal. Callers therefore must NOT wrap sections in a
      # card of their own; they supply a plain stacking container.
      #
      # The caller supplies the fields as a block and owns what a "field" means.
      class Section < Plutonium::UI::Component::Base
        # Default section chrome, merged into BOTH Form::Theme and
        # Display::Theme so the two read identically out of the box while each
        # stays independently overridable — the same contract every other
        # themed key has. Defined here rather than written out twice so the
        # shipped defaults cannot drift between the form and the show page.
        #
        # Structure (which element gets which key, the `group`/[open]
        # mechanics) stays in this component; themes own the classes.
        DEFAULT_THEME = {
          # Merged into the section's {Plutonium::UI::Block} card — Block
          # supplies `pu-card` itself, so this only adds what is specific to a
          # section. `overflow-hidden` keeps the header row's fill and border
          # inside the card's rounded corners.
          section_wrapper: "overflow-hidden",

          # Header row. Its bottom border is the line between the header and
          # the fields — the card edge already separates one section from the
          # next, so nothing else has to.
          section_header:
            "px-4 py-3 flex items-center gap-3 " \
            "border-b border-[var(--pu-border)] bg-[var(--pu-surface-alt)]",

          # A short primary bar at the head of the row. A standalone element
          # rather than a border on the text block, so the heading and its
          # description stay vertically centred against it.
          section_accent: "shrink-0 w-1 h-5 rounded-full bg-primary-500",

          # Sized to sit under the page title (text-xl semibold) while
          # out-ranking display values (text-lg regular) and field labels.
          # With the card doing the separating, the heading no longer has to
          # shout to be read as a header.
          section_heading: "text-base font-bold tracking-tight text-[var(--pu-text)]",
          section_description: "text-sm font-normal text-[var(--pu-text-muted)]",

          # `list-none` + the WebKit marker reset remove the native disclosure
          # triangle, which the browser pins to the LEFT of the summary — where
          # it would displace the accent bar and knock the heading out of the
          # alignment every other section keeps. The caret is re-drawn on the
          # right instead, so headers stay identical whether or not a section
          # happens to be collapsible.
          # The divider only exists to separate the header from the fields, so
          # a COLLAPSED section must not draw one — there is nothing below it,
          # and the line would land directly on the card's own bottom border.
          # `group-open:` keys it to the parent <details>'s [open] state.
          section_summary:
            "px-4 py-3 flex items-center gap-3 cursor-pointer select-none " \
            "border-b-0 group-open:border-b border-[var(--pu-border)] " \
            "bg-[var(--pu-surface-alt)] " \
            "list-none [&::-webkit-details-marker]:hidden",

          section_caret:
            "shrink-0 w-3 h-3 text-[var(--pu-text-muted)] " \
            "transition-transform duration-200 group-open:rotate-180",

          # Padding box between the card edge and the field grid.
          section_body: "pu-card-body"
        }.freeze

        # The theme this section's chrome resolves against. Subclasses name
        # their own, so a form section follows Form::Theme and a show-page
        # section follows Display::Theme.
        def self.theme_class
          raise NotImplementedError, "#{self} must implement .theme_class"
        end

        def initialize(resolved, grid_class:)
          @section = resolved.section
          @grid_class = grid_class
        end

        # Every section is a {Plutonium::UI::Block} — the shared card primitive
        # — so a section card and any other card on the page are the same
        # surface by construction rather than by two lists of classes that
        # happen to agree today.
        def view_template(&fields_block)
          Block(class: themed_section(:section_wrapper)) do
            if @section.collapsible?
              # `group` lets the caret rotate off the <details>'s [open] state.
              details(open: !@section.collapsed?, class: "group") do
                # <summary> must be the first child of <details> and can't be
                # wrapped, so it IS the header row.
                summary(class: themed_section(:section_summary)) do
                  span(class: themed_section(:section_accent))
                  heading_block
                  render_caret
                end
                body(&fields_block)
              end
            else
              header_row
              body(&fields_block)
            end
          end
        end

        private

        def themed_section(key)
          self.class.theme_class.instance.resolve_theme(key)
        end

        # An unlabelled `ungrouped` bucket gets no header row at all — just a
        # card holding its leftover fields.
        def header_row
          return if headerless?
          div(class: themed_section(:section_header)) do
            span(class: themed_section(:section_accent))
            heading_block
          end
        end

        def headerless? = @section.ungrouped? && @section.options[:label].nil?

        # Title over description, taking the free space in the row so the caret
        # is pushed to the far right.
        def heading_block
          div(class: "min-w-0 flex-1") do
            h3(class: themed_section(:section_heading)) { heading_text }
            describe
          end
        end

        def heading_text = @section.label

        def describe
          return unless @section.description
          p(class: themed_section(:section_description)) { @section.description }
        end

        # Points down when open, up when closed (rotate-180). Decorative — the
        # <summary> element already carries the expand/collapse semantics for
        # assistive tech, so this is aria-hidden.
        def render_caret
          svg(
            class: themed_section(:section_caret),
            aria_hidden: "true",
            xmlns: "http://www.w3.org/2000/svg",
            fill: "none",
            viewbox: "0 0 10 6"
          ) do |s|
            s.path(
              stroke: "currentColor",
              stroke_linecap: "round",
              stroke_linejoin: "round",
              stroke_width: "2",
              d: "M1 1l4 4 4-4"
            )
          end
        end

        def body(&fields_block)
          div(class: themed_section(:section_body)) do
            div(class: @grid_class, &fields_block)
          end
        end
      end
    end
  end
end
