# frozen_string_literal: true

module OrgPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Public

      private

      # Override to skip associated_with scoping since Public auth returns "Guest" (not a model)
      def fetch_entity_from_path
        scoped_entity_class
          .from_path_param(request.path_parameters[scoped_entity_param_key])
          .first!
      end
    end
  end
end
