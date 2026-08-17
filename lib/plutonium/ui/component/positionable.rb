# frozen_string_literal: true

module Plutonium
  module UI
    module Component
      # Drag-to-reorder plumbing shared by every index surface that renders a
      # collection of a `position_on` resource — the table (Table::Resource) and
      # the card grid (Grid::Resource).
      #
      # Extracted rather than copied because the two halves of this feature have
      # to agree EXACTLY: the client only offers a drag under the same condition
      # the server accepts one, and the URL template the client substitutes into
      # has to be the collection's own path. Two copies of that reasoning is two
      # places for the client and the server to drift apart.
      #
      # A host must supply `resource_definition`, `current_query_object`,
      # `current_page_path` and `policy_for` — everything Component::Base's
      # index views already have.
      module Positionable
        private

        # The resource's positioning strategy, or nil when it declares none /
        # declares `position_on false`. Everything else here hangs off this.
        def position_config
          return @position_config if defined?(@position_config)

          config = resource_definition.defined_position_config
          @position_config = (config && !config.disabled?) ? config : nil
        end

        # Whether a drop can be honoured RIGHT NOW.
        #
        # Dropping "between the two records either side of me" only describes a
        # position when the visual order IS the stored order. Under a title sort
        # the neighbours say nothing; under a DESCENDING position sort they say
        # the opposite of what the write would assume. The server rejects both
        # (422, no write) — this is the client half of that same rule, and it
        # deliberately reuses the server's own predicate rather than restating it.
        def position_drag_enabled?
          return false unless position_config

          current_query_object.sorted_ascending_only_by?(position_config.attribute)
        end

        # The URL that puts the collection back into ascending position order —
        # what the disabled grip links to. Built off the registered sort (see
        # Definition::Positioning#position_on), which flips to ASC from a
        # descending position sort and starts at ASC from any other sort.
        def position_sort_url
          current_query_object.sort_params_for(position_config.attribute)[:url]
        end

        # What to hand a grip: nil while dragging is live, otherwise the sort URL
        # that makes it live. Memoized because it depends on the collection's
        # sort, not on the record — re-deriving it per row would rebuild the same
        # URL for every row of every page.
        def position_grip_sort_url
          return @position_grip_sort_url if defined?(@position_grip_sort_url)

          @position_grip_sort_url = position_drag_enabled? ? nil : position_sort_url
        end

        # The member reposition path with an __ID__ placeholder for the client to
        # substitute. Mirrors Kanban::Resource#kanban_move_url_template, but off
        # `current_page_path` rather than `request.path`: after a rebalance the
        # endpoint re-renders this very collection from a POST to
        # /things/5/reposition, and a template derived from THAT request would
        # send every subsequent drop to a nested path that does not exist.
        def position_url_template
          "#{current_page_path.delete_suffix("/")}/__ID__/reposition"
        end

        # Whether THIS viewer may reorder THIS record. Has to run per record —
        # it is what keeps someone who may not reorder a given record from being
        # offered a grip that can only ever answer 403.
        def repositionable?(record)
          policy_for(record:).allowed_to?(:reposition?)
        end

        # Which positioning GROUP a record sits in, or nil when every record on
        # the surface shares one list.
        #
        # A scoped resource (`positioned_on :position, scope: :product_id`) keeps
        # an independent 1..n sequence per group, so a top-level index that spans
        # groups interleaves several sequences. A drop between two records from
        # DIFFERENT groups describes no position at all, and the server refuses
        # it (see PositionActions#resolve_position_neighbour, which rejects a
        # neighbour whose scope attribute differs). This is the client half of
        # that same rule — the value goes on the row so the drag can refuse
        # before the user commits, instead of snapping back afterwards.
        #
        # Guarded on `delegate?` exactly as the server is: Mode B owns its own
        # notion of a group, and nothing out here may second-guess it.
        def position_group_for(record)
          return nil unless position_config&.delegate?

          attr = record.class.positioning_scope_attr
          attr && record[attr]
        end

        # Passed to the collection components, which have no access to the
        # definition and must not grow any. nil when the resource is unscoped, so
        # the attribute is omitted entirely rather than emitted empty.
        def position_group_resolver
          return nil unless position_config&.delegate?

          method(:position_group_for)
        end
      end
    end
  end
end
