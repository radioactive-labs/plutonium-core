# frozen_string_literal: true

require "phlex"

module Plutonium
  module UI
    module Component
      module Methods
        extend ActiveSupport::Concern

        private

        def params
          view_context.controller.params
        end

        def request
          view_context.controller.request
        end

        def pagy_instance
          view_context.controller.instance_variable_get(:@pagy)
        end

        def controller
          view_context.controller
        end

        delegate \
          :main_app,
          :resource_class,
          :resource_record!,
          :resource_record?,
          :resource_name,
          :resource_name_plural,
          :nestable_resource_name_plural,
          :display_name_of,
          :resource_url_for,
          :route_options_to_url,
          :current_user,
          :current_parent,
          :current_definition,
          :current_query_object,
          :raw_resource_query_params,
          :current_policy,
          :current_turbo_frame,
          :current_interactive_action,
          :current_engine,
          :policy_for,
          :authorized_resource_scope,
          :allowed_to?,
          :registered_resources,
          :root_path,
          :make_page_title,
          :resource_logo_tag,
          to: :view_context
      end
    end
  end
end
