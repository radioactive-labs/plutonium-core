# frozen_string_literal: true

module Plutonium
  module UI
    module Grid
      # Renders a single record as a card built from semantic slots
      # (image / header / subheader / body / meta / footer) declared via
      # `grid_fields` on the resource definition. Each slot is optional;
      # `header` falls back to `record.to_label` when undeclared.
      class Card < Plutonium::UI::Component::Base
        attr_reader :record, :resource_definition

        def initialize(record, resource_definition:)
          @record = record
          @resource_definition = resource_definition
        end

        def view_template
          article(
            class: card_class,
            data: {controller: "row-click", action: "click->row-click#click"}
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

        def slots = resource_definition.defined_grid_fields

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
          return unless value
          src = image_src_for(value)
          return unless src

          if size == :cover
            div(class: "w-full aspect-video bg-[var(--pu-surface-alt)] overflow-hidden") do
              img(src: src, alt: header_text.to_s, class: "w-full h-full object-cover")
            end
          else
            img(
              src: src,
              alt: header_text.to_s,
              class: "w-12 h-12 rounded-full object-cover bg-[var(--pu-surface-alt)] shrink-0"
            )
          end
        end

        def render_header_slot
          h3(class: "text-sm font-semibold text-[var(--pu-text)] truncate") do
            plain header_text
          end
        end

        def render_subheader_slot
          value = field_value(slots[:subheader])
          return if value.blank?
          p(class: "text-xs text-[var(--pu-text-muted)] truncate") { plain helpers.display_name_of(value) }
        end

        def render_body_slot
          value = field_value(slots[:body])
          return if value.blank?
          p(class: "text-sm text-[var(--pu-text)] line-clamp-3") { plain helpers.display_name_of(value) }
        end

        def render_meta_slot
          fields = Array(slots[:meta])
          values = fields.map { |f| field_value(f) }.reject(&:blank?)
          return if values.empty?

          div(class: "flex flex-wrap items-center gap-1.5 mt-1") do
            values.each do |v|
              span(class: "inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-medium " \
                          "bg-[var(--pu-surface-alt)] text-[var(--pu-text-muted)]") do
                plain helpers.display_name_of(v)
              end
            end
          end
        end

        def render_footer_slot
          value = field_value(footer_field)
          return if value.blank?
          p(class: "text-xs text-[var(--pu-text-subtle)] mt-1") do
            if value.respond_to?(:strftime)
              # display_datetime_value returns HTML-safe <time> markup
              # rendered by the timeago Stimulus controller.
              raw safe(helpers.display_datetime_value(value))
            else
              plain helpers.display_name_of(value)
            end
          end
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
            data: {row_click_target: "show", turbo_frame: show.turbo_frame},
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
          unless record.respond_to?(name)
            raise ArgumentError,
              "grid_fields slot points at `:#{name}` but " \
              "#{record.class.name} doesn't respond to it. " \
              "Define the method on the model or remove the slot."
          end
          record.public_send(name)
        end

        # Resolves a slot value to an image URL. Supports:
        # - ActiveStorage attachments (`record.avatar` -> Attached::One/Many)
        # - Shrine uploaders (`record.avatar` -> UploadedFile, responds to :url)
        # - Plain URL strings ("https://..." or "/uploads/...")
        def image_src_for(value)
          return nil if value.nil?
          if value.respond_to?(:attached?)
            value.attached? ? helpers.url_for(value) : nil
          elsif value.respond_to?(:url)
            value.url
          elsif value.is_a?(String) && value.start_with?("http", "/")
            value
          end
        rescue ArgumentError, URI::InvalidURIError
          nil
        end

        def row_actions
          @row_actions ||= resource_definition.defined_actions.values.select { |a|
            a.collection_record_action? && a.permitted_by?(record_policy)
          }
        end

        def can_show?
          resource_definition.defined_actions[:show]&.permitted_by?(record_policy)
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
