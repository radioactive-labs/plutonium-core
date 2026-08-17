# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Index < Base
        # Cookie name carrying a per-resource view preference. Single
        # source of truth — Table::Resource, Grid::Resource, and the
        # Stimulus view-switcher controller all read from here. Underscored
        # token-only characters keep this RFC 6265-compliant (the `:` form
        # this replaces is technically forbidden, even if browsers
        # accept it in practice).
        def self.view_cookie_name(resource_class)
          "pu_view_#{resource_class.name.gsub("::", "_").underscore}"
        end

        # Cookie Path scoped to the engine mount point (request.script_name).
        # Two portals mounting the same resource class get independent
        # view preferences instead of leaking through a site-wide cookie.
        def self.view_cookie_path(request)
          path = request.script_name.to_s
          path.empty? ? "/" : path
        end

        # DOM id of the wrapper around the rendered collection (table OR grid;
        # never the kanban board, which owns its own column frames).
        #
        # This is the turbo-stream target the reposition endpoint updates when a
        # drop leaves the client's optimistic view stale, and the element the
        # drag controllers (Tasks 7/8) scope themselves to. Resource-scoped so
        # two collections of DIFFERENT resources on one page (a nested
        # association panel inside a show page) don't collide.
        def self.collection_dom_id(resource_class)
          "pu-collection-#{resource_class.model_name.plural}"
        end

        # Resolves the index view to render. Extracted to a class method because
        # the reposition endpoint has to re-render the SAME view the user is
        # looking at, and re-deriving that from scratch in the controller would
        # be a second, drifting copy of this precedence.
        #
        # Resolution order:
        # 1. `?view=` URL param (so a shared link can pin a view)
        # 2. The view-preference cookie (sticky per-resource selection)
        # 3. The resource's `default_index_view` (which itself defaults to
        #    `index_views.first`)
        def self.resolve_view(definition, resource_class, view_param, cookies)
          enabled = definition.defined_index_views

          requested = view_param&.to_sym
          return requested if requested && enabled.include?(requested)

          stored = cookies[view_cookie_name(resource_class)]&.to_sym
          return stored if stored && enabled.include?(stored)

          definition.default_index_view
        end

        private

        def page_title
          super || current_definition.index_page_title || nestable_resource_name_plural(resource_class)
        end

        def page_description
          super || current_definition.index_page_description
        end

        def page_actions
          super || current_definition.defined_actions.values.select { |a| a.resource_action? && !a.hidden? && a.permitted_by?(current_policy) && a.condition_met?(view_context) }
        end

        def render_default_content
          # The board owns its own frames (and its own drop target), so it is
          # rendered bare. Table and grid share one id'd wrapper: it is what the
          # reposition endpoint streams into after a drop, so the surface the
          # drag controller reads and the surface the server replaces are the
          # same element in both views.
          render_running_banner

          return render partial("resource_kanban") if selected_view == :kanban

          div(id: self.class.collection_dom_id(resource_class)) do
            render partial((selected_view == :grid) ? "resource_grid" : "resource_table")
          end
        end

        # Runs currently working on this resource, above the collection.
        #
        # Rendered OUTSIDE the collection wrapper on purpose: that div is what
        # the reposition endpoint streams into after a drag, so anything inside
        # it is destroyed on the next drop.
        #
        # Scoped through authorized_resource_scope, the same door every other
        # cross-resource read goes through, so a run dispatched in another tenant
        # can never appear here — the banner cannot be a way around the policy.
        def render_running_banner
          return unless Plutonium.configuration.interaction_runs.enabled

          runs = authorized_resource_scope(
            Plutonium::Interaction::Run,
            relation: Plutonium::Interaction::Run.for_target(resource_class).in_progress
          ).to_a

          render Plutonium::UI::Interaction::RunningBanner.new(runs: runs)
        end

        def selected_view
          self.class.resolve_view(current_definition, resource_class, params[:view], helpers.cookies)
        end

        def page_type = :index_page
      end
    end
  end
end
