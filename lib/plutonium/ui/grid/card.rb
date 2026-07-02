# frozen_string_literal: true

module Plutonium
  module UI
    module Grid
      # Renders a single record as a card built from semantic slots
      # (image / header / subheader / body / meta / footer) declared via
      # `grid_fields` on the resource definition. Each slot is optional;
      # `header` falls back to `record.to_label` when undeclared.
      class Card < Plutonium::UI::Component::Base
        attr_reader :record, :resource_definition, :resource_fields, :card_fields

        def initialize(record, resource_definition:, resource_fields: nil, card_fields: nil, show_turbo_frame: nil)
          @record = record
          @resource_definition = resource_definition
          @resource_fields = resource_fields
          @card_fields = card_fields
          # Overrides the show link's turbo-frame target. Defaults to the show
          # action's own frame (nil → normal navigation). The kanban board sets
          # "_top" so a card click escapes its column's lazy turbo-frame instead
          # of loading the show page inside the column.
          @show_turbo_frame = show_turbo_frame
        end

        def view_template
          article(
            class: card_class,
            data: {controller: "row-click", action: "click->row-click#click auxclick->row-click#click"}
          ) do
            render_show_link if can_show?
            render_actions_dropdown
            case resource_definition.defined_grid_layout
            when :media then render_media_layout
            else render_compact_layout
            end
          end
        end

        private

        # Returns the slot hash used for rendering.
        # When the kanban board declares `card_fields`, it is passed in
        # explicitly and takes precedence over the resource definition's
        # `defined_grid_fields`.  A nil card_fields falls back to the
        # definition, which is the default for the grid view.
        def slots = @card_fields || resource_definition.defined_grid_fields

        # ---------------------------------------------------------------
        # Layout shells
        # ---------------------------------------------------------------

        def render_compact_layout
          div(class: "flex items-start gap-3 p-4") do
            render_image_slot(size: :sm) if slots[:image]
            div(class: "min-w-0 flex-1 flex flex-col gap-1") do
              render_header_slot
              render_subheader_slot if slots[:subheader]
              render_body_slot if slots[:body]
              render_meta_slot if slots[:meta]
              render_footer_slot if footer_field
            end
          end
        end

        def render_media_layout
          render_image_slot(size: :cover) if slots[:image]
          div(class: "p-4 flex flex-col gap-1") do
            render_header_slot
            render_subheader_slot if slots[:subheader]
            render_body_slot if slots[:body]
            render_meta_slot if slots[:meta]
            render_footer_slot if footer_field
          end
        end

        # Footer falls back to `:created_at` when the slot is unset and
        # the record has a created_at column. Gives cards a sensible
        # second line without forcing every grid_fields call to repeat it.
        def footer_field
          slots[:footer] || (record.respond_to?(:created_at) ? :created_at : nil)
        end

        # ---------------------------------------------------------------
        # Slot renderers
        # ---------------------------------------------------------------

        def render_image_slot(size:)
          value = field_value(slots[:image])

          if size == :cover
            # Cover is a full-width banner, not an avatar: only render when an
            # actual image resolves (no deterministic fallback).
            src = Plutonium::UI::Avatar.resolve_image_src(value, helpers)
            return unless src

            div(class: "w-full aspect-video bg-[var(--pu-surface-alt)] overflow-hidden") do
              img(src: src, alt: header_text.to_s, class: "w-full h-full object-cover")
            end
          else
            # Small avatar slot: render the resolved image, or Avatar's generic
            # icon fallback. No subject is passed, so image-less cards fall back
            # to the local icon rather than a per-card request to Navii.
            Avatar(src: value, size: :lg, alt: header_text.to_s)
          end
        end

        def render_header_slot
          h3(class: "text-sm font-semibold text-[var(--pu-text)] truncate") do
            plain header_text
          end
        end

        def render_subheader_slot
          name = slots[:subheader]
          value = field_value(name)
          p(class: "text-xs text-[var(--pu-text-muted)] truncate") do
            value.blank? ? render_blank_placeholder : render_formatted_value(name, value)
          end
        end

        def render_body_slot
          name = slots[:body]
          value = field_value(name)
          p(class: "text-sm text-[var(--pu-text)] line-clamp-3") do
            value.blank? ? render_blank_placeholder : render_formatted_value(name, value)
          end
        end

        def render_meta_slot
          pairs = Array(slots[:meta]).map { |name| [name, field_value(name)] }.reject { |_, value| value.blank? }

          div(class: "flex flex-wrap items-center gap-1.5 mt-1") do
            if pairs.empty?
              render_blank_placeholder
            else
              pairs.each { |name, value| render_meta_badge(name, value) }
            end
          end
        end

        def render_footer_slot
          name = footer_field
          value = field_value(name)
          p(class: "text-xs text-[var(--pu-text-subtle)] mt-1") do
            value.blank? ? render_blank_placeholder : render_formatted_value(name, value)
          end
        end

        # Emits a slot value formatted by type, reusing the display layer's
        # logic without its show-page label/wrapper chrome:
        #   - dates/times → timeago markup (same path as the footer used)
        #   - has_cents columns → currency (matches the Currency component)
        #   - everything else → display_name_of
        def render_formatted_value(name, value)
          if value.respond_to?(:strftime)
            # display_datetime_value returns HTML-safe <time> markup
            # rendered by the timeago Stimulus controller.
            raw safe(helpers.display_datetime_value(value))
          elsif currency_field?(name)
            plain helpers.number_to_currency(value, unit: currency_unit_for(name))
          else
            plain helpers.display_name_of(value)
          end
        end

        # Renders a meta value as a colored pill, borrowing the Badge display
        # component's semantic color + humanize logic. Non-string types are
        # formatted by type first so they don't badge their raw value:
        #   - has_cents columns → currency (matches render_formatted_value)
        #   - associations → display_name_of (label, not an object inspect)
        #   - everything else → humanized, with the RAW value driving the
        #     variant so status-like enums (in_progress, published…) still
        #     resolve to a semantic color.
        # The variant hashes the stable formatted label for currency/associations,
        # so the decorative color no longer churns on an object's memory address.
        def render_meta_badge(name, value)
          badge = Plutonium::UI::Display::Components::Badge

          if currency_field?(name)
            label = helpers.number_to_currency(value, unit: currency_unit_for(name))
            variant = badge.variant_for(label)
          elsif association_field?(name)
            label = helpers.display_name_of(value)
            variant = badge.variant_for(label)
          else
            label = badge.humanize(value)
            variant = badge.variant_for(value)
          end

          span(class: tokens("pu-badge", "pu-badge-#{variant}")) do
            plain label
          end
        end

        def currency_field?(name)
          klass = record.class
          klass.respond_to?(:has_cents_decimal_attribute?) && klass.has_cents_decimal_attribute?(name.to_sym)
        end

        # Delegates to the shared resolver so cards format currency identically to
        # the Currency display component — has_cents unit → configured/i18n default,
        # with `false` meaning no symbol. Cards have no per-display unit (nil).
        def currency_unit_for(name)
          Plutonium::UI::Display::Components::Currency.resolve_unit(nil, record, name)
        end

        def association_field?(name)
          record.class.reflect_on_association(name.to_sym).present?
        end

        # A declared slot with no value renders a muted em-dash rather than
        # collapsing, so cards in a grid keep an even height instead of
        # ragged rows when some records lack the field.
        def render_blank_placeholder
          span(class: "text-[var(--pu-text-subtle)]") { plain "—" }
        end

        # ---------------------------------------------------------------
        # Card chrome — selection, actions, show
        # ---------------------------------------------------------------

        def render_actions_dropdown
          # Cards have limited surface area, so all collection-record
          # actions (including primary ones like Edit) live in the
          # dropdown rather than splitting between buttons and a menu
          # like the table view does.
          actions = row_actions.reject { |a| a.name == :show }
          return if actions.empty?
          div(class: "absolute top-2 right-2 z-10") do
            RowActionsDropdown(actions: actions, record:)
          end
        end

        # Hidden link the `row-click` controller delegates to when the
        # user clicks anywhere on the card body. Mirrors how the show
        # action button works in the Table view.
        def render_show_link
          show = resource_definition.defined_actions[:show]
          url = route_options_to_url(show.route_options, record)
          a(
            href: url,
            data: {row_click_target: "show", turbo_frame: @show_turbo_frame || show.turbo_frame(resource_definition)},
            class: "sr-only",
            tabindex: "-1",
            "aria-label": "Open #{header_text}"
          ) { plain "Open" }
        end

        # ---------------------------------------------------------------
        # Helpers
        # ---------------------------------------------------------------

        def header_text
          @header_text ||= helpers.display_name_of(field_value(slots[:header]) || record)
        end

        def field_value(name)
          return nil unless name
          # Skip fields the user's policy doesn't permit. nil collapses
          # the slot in render_*_slot guards above.
          return nil if resource_fields && !resource_fields.include?(name.to_sym)
          unless record.respond_to?(name)
            raise ArgumentError,
              "grid_fields slot points at `:#{name}` but " \
              "#{record.class.name} doesn't respond to it. " \
              "Define the method on the model or remove the slot."
          end
          record.public_send(name)
        end

        def row_actions
          @row_actions ||= resource_definition.defined_actions.values.select { |a|
            a.collection_record_action? && a.permitted_by?(record_policy) && a.condition_met?(view_context, record:)
          }
        end

        def can_show?
          action = resource_definition.defined_actions[:show]
          action&.permitted_by?(record_policy) && action.condition_met?(view_context, record:)
        end

        def record_policy
          @record_policy ||= policy_for(record:)
        end

        def card_class
          tokens(
            "pu-card relative overflow-hidden transition-shadow",
            -> { can_show? } => "cursor-pointer hover:shadow-md focus-within:ring-2 focus-within:ring-primary-500"
          )
        end
      end
    end
  end
end
