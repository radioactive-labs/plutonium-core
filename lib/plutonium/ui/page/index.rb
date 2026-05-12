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

        private

        def page_title
          super || current_definition.index_page_title || nestable_resource_name_plural(resource_class)
        end

        def page_description
          super || current_definition.index_page_description
        end

        def page_actions
          super || current_definition.defined_actions.values.select { |a| a.resource_action? && a.permitted_by?(current_policy) }
        end

        def render_default_content
          case selected_view
          when :grid then render partial("resource_grid")
          else render partial("resource_table")
          end
        end

        # Resolution order:
        # 1. `?view=` URL param (so a shared link can pin a view)
        # 2. The view-preference cookie (sticky per-resource selection)
        # 3. The resource's `default_index_view` (which itself defaults to
        #    `index_views.first`)
        def selected_view
          definition = current_definition
          enabled = definition.defined_index_views

          requested = params[:view]&.to_sym
          return requested if requested && enabled.include?(requested)

          stored = helpers.cookies[self.class.view_cookie_name(resource_class)]&.to_sym
          return stored if stored && enabled.include?(stored)

          definition.default_index_view
        end

        def page_type = :index_page
      end
    end
  end
end
