# frozen_string_literal: true

module Plutonium
  module UI
    module Kanban
      # Board shell — renders one lazy turbo-frame per column.
      #
      # Each frame id is "kanban-col-<key>". Its src merges view=kanban and
      # column=<key> into the current request URL so Task 6's column endpoint
      # fills the body on demand. The frame already contains the column header
      # (color dot + label) so the shell is meaningful while the body loads. The
      # header deliberately omits a card-count badge: the shell has no card data,
      # so a "0" would flash then vanish when Kanban::Column (which renders no
      # count badge) replaces the frame body.
      #
      # The outer wrapper carries data-controller="kanban" for the Stimulus
      # drag controller wired in Task 11.
      #
      # Realtime subscription: when board.realtime? is true,
      # render_realtime_subscription is called before the board wrapper.
      # Task 14 implements the broadcaster and fills in that method body.
      class Resource < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::TurboFrameTag
        include Phlex::Rails::Helpers::TurboStreamFrom

        attr_reader :board, :grouped_data, :resource_definition, :resource_fields,
          :resource_class, :scoped_entity

        def initialize(board:, grouped_data:, resource_definition:, resource_fields:,
          resource_class: nil, scoped_entity: nil)
          @board = board
          @grouped_data = grouped_data
          @resource_definition = resource_definition
          # TODO (Tasks 6/10): resource_fields arrives ALREADY resolved — the
          # column endpoint / index page is responsible for the
          # `board.card_fields || definition.grid_fields` fallback before
          # constructing this component. Kanban::Resource (and the Card it
          # eventually builds) just receives the final field list and renders
          # it; it does not resolve card_fields itself.
          @resource_fields = resource_fields
          # Used by render_realtime_subscription (Task 14) to scope the
          # ActionCable stream to the correct tenant + resource.
          @resource_class = resource_class
          @scoped_entity = scoped_entity
        end

        def view_template
          # Hook for Task 14 — no-op until the realtime broadcaster is wired.
          render_realtime_subscription if board.realtime?

          div(
            class: "pu-kanban-board flex gap-4 overflow-x-auto p-4 min-h-0",
            data: {
              controller: "kanban",
              # Stimulus value consumed by the drag controller to build the
              # per-record move URL at drop time. The collection path comes from
              # request.path so tenant / engine scoping is preserved automatically.
              # Example: /admin/tasks/__ID__/kanban_move
              kanban_move_url_template_value: kanban_move_url_template
            }
          ) do
            grouped_data.each do |entry|
              render_column_frame(entry[:column])
            end
          end
        end

        private

        # Emits a <turbo-cable-stream-source> element that subscribes this page
        # to the kanban board's tenant-scoped ActionCable stream.
        #
        # Only called when board.realtime? is true (gated by the caller in
        # view_template). The stream name matches the one used by
        # Plutonium::Kanban::Broadcaster#broadcast so move events reach exactly
        # the right subscribers.
        def render_realtime_subscription
          turbo_stream_from(
            *Plutonium::Kanban::Broadcaster.stream_name(
              resource_class: resource_class,
              scoped_entity: scoped_entity
            )
          )
        end

        def render_column_frame(column)
          attrs = {src: column_frame_src(column)}
          attrs[:loading] = "lazy" if board.lazy?

          turbo_frame_tag(column_frame_id(column), **attrs) do
            # Header is inside the frame so the shell is meaningful while the
            # body (card list) loads. Task 6 replaces the frame contents with
            # the full column body rendered by Kanban::Column.
            render_column_header(column)
          end
        end

        # Mirrors Kanban::Column#render_header structurally (no count badge) so
        # the shell→loaded transition doesn't flash a stale count or restructure.
        def render_column_header(column)
          div(class: "px-3 py-2 flex items-center justify-between border-b border-[var(--pu-border)] bg-[var(--pu-surface)]") do
            div(class: "flex items-center gap-2 min-w-0") do
              render_color_dot(column.color) if column.color
              span(class: "font-semibold text-sm text-[var(--pu-text)] truncate") { plain column.label }
            end
          end
        end

        def render_color_dot(color)
          span(
            class: "shrink-0 w-2.5 h-2.5 rounded-full",
            style: "background-color: #{color_css_value(color)}"
          )
        end

        # Maps a column color symbol to a CSS value via Tailwind design tokens.
        # Raw CSS strings (e.g. "#ff0000") are passed through unchanged.
        def color_css_value(color)
          case color.to_sym
          when :red    then "var(--color-red-500)"
          when :orange then "var(--color-orange-500)"
          when :yellow then "var(--color-yellow-500)"
          when :green  then "var(--color-green-500)"
          when :blue   then "var(--color-blue-500)"
          when :purple then "var(--color-purple-500)"
          when :pink   then "var(--color-pink-500)"
          when :gray   then "var(--pu-text-muted)"
          else color.to_s
          end
        end

        # Builds the move URL template for the Stimulus drag controller.
        # The collection path from the current request is used so engine
        # mounting and path-scoped tenancy are automatically preserved.
        # The literal string "__ID__" is a placeholder; the JS controller
        # replaces it with the dragged card's record id at drop time.
        def kanban_move_url_template
          base = request.path.delete_suffix("/")
          "#{base}/__ID__/kanban_move"
        end

        # Returns the turbo-frame element id for a column.
        # Plain id — not turbo_scoped_dom_id which is for modal-frame scoping.
        def column_frame_id(column)
          "kanban-col-#{column.key}"
        end

        # Builds the frame src URL from the current request path + merged params.
        # Merges view=kanban and column=<key> so the column endpoint (Task 6)
        # knows which column to render without requiring an explicit route param.
        def column_frame_src(column)
          merged = request.query_parameters.merge(
            "view" => "kanban",
            "column" => column.key.to_s
          )
          "#{request.path}?#{merged.to_query}"
        end
      end
    end
  end
end
