# frozen_string_literal: true

module Plutonium
  module Core
    class AdminResourceController < ResourceController
      # include CurrentAdmin
      # include Concerns::CurrentParent
      # include Concerns::RouteArgsAdapter

      def adapt_route_args(*args, action: nil, use_parent: true, **kwargs)
        # If the last item is a class and an action is passed e.g. `adapt_route_args User, action: :new`,
        # it must be converted into a symbol to generate the appropriate helper i.e `new_entity_user_*`
        resource = args.pop
        resource = resource.to_s.underscore.to_sym if action.present? && resource.is_a?(Class)
        args.push resource

        parent = use_parent ? current_parent : nil

        # # rails compacts this list. no need to handle nils
        [action, parent] + args + [**kwargs]
      end
      helper_method :adapt_route_args

      def current_parent
        return unless parent_param_key.present?

        @current_parent ||= begin
          parent_name = parent_param_key.to_s.gsub(/_id$/, "")

          parent_class = parent_name.classify.constantize
          parent_class.from_path_param(params[parent_param_key]).first!
        end
      end
      helper_method :current_parent

      def parent_param_key
        @parent_param_key ||= begin
          path_param_keys = params.keys.last(4) - %w[controller action entity_id id format]
          path_param_keys.reverse.find { |key| /_id$/.match? key }&.to_sym
        end
      end

      private

      def rodauth(key = :admin)
        super(key)
      end

      def current_user
        current_admin
      end
      helper_method :current_user

      # Presentation

      def resource_presenter(resource_class)
        admin_resource_presenter = "#{resource_class.to_s.classify.pluralize}::AdminPresenter".constantize
        admin_resource_presenter.new resource_context, resource_class
      end

      # Layout

      def build_sidebar_menu
        {
          dashboard: {
            home: admin_path
          },
          events: {
            events: admin_ticketed_events_path,
            tickets: admin_ticketed_events_tickets_path,
            bundles: admin_ticketed_events_bundles_path,
            organisers: admin_event_organisers_path
          },
          config: {
            ticket_categories: admin_ticketed_events_tickets_categories_path,
            ticket_experiences: admin_ticketed_events_tickets_experiences_path
          },
          admin: {
            users: admin_users_path
          }
        }
      end

      # Authorisation

      def policy_namespace(scope)
        [:resources, :admin, scope]
      end
    end
  end
end
