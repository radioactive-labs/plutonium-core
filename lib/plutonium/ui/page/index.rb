# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      class Index < Base
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
          else            render partial("resource_table")
          end
        end

        # Resolution order:
        # 1. `?view=` URL param (so a shared link can pin a view)
        # 2. The view-preference cookie (sticky per-resource selection)
        # 3. The resource's `default_view` (which itself defaults to
        #    `views.first`)
        def selected_view
          definition = current_definition
          enabled = definition.defined_views

          requested = params[:view]&.to_sym
          return requested if requested && enabled.include?(requested)

          stored = view_cookie_value&.to_sym
          return stored if stored && enabled.include?(stored)

          definition.default_view
        end

        def view_cookie_value
          helpers.cookies[view_cookie_name]
        end

        def view_cookie_name
          "pu_view:#{resource_class.name}"
        end

        def page_type = :index_page
      end
    end
  end
end
