# frozen_string_literal: true

require "phlex"

module Plutonium
  module UI
    module Component
      module Methods
        extend ActiveSupport::Concern

        private

        def resource_class
          helpers.controller.send(:resource_class)
        end

        def resource_record
          helpers.controller.send(:resource_record)
        end

        def current_parent
          helpers.controller.send(:current_parent)
        end

        def params
          helpers.controller.params
        end

        def request
          helpers.controller.request
        end

        def pagy_instance
          helpers.controller.instance_variable_get(:@pagy)
        end

        delegate \
          :resource_name,
          :resource_name_plural,
          :display_name_of,
          :resource_url_for,
          :current_definition,
          :current_query_object,
          :raw_resource_query_params,
          :current_policy,
          :current_turbo_frame,
          :current_interactive_action,
          :policy_for,
          :allowed_to?,
          :registered_resources,
          to: :helpers
      end
    end
  end
end
