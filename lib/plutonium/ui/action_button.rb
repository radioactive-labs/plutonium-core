# frozen_string_literal: true

module Plutonium
  module UI
    class ActionButton < Plutonium::UI::Component::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTo

      def initialize(action, url:, variant: :default)
        @action = action
        @url = url
        @variant = variant
      end

      def view_template
        if @action.route_options.method == :get
          render_link
        else
          render_button
        end
      end

      private

      def render_link
        uri = URI.parse(@url)
        params = Rack::Utils.parse_nested_query(uri.query)
        params["return_to"] = request.original_url
        uri.query = params.to_query
        uri.to_s

        link_to(
          uri.to_s,
          class: button_classes,
          data: {turbo_frame: @action.turbo_frame}
        ) do
          render_button_content
        end
      end

      def render_button
        button_to(
          @url,
          method: @action.route_options.method,
          name: :return_to, value: request.original_url,
          class: "inline-block",
          form: {
            data: {
              turbo: @action.turbo,
              turbo_confirm: @action.confirmation,
              turbo_frame: @action.turbo_frame
            }
          }
        ) do
          span(class: button_classes) do
            render_button_content
          end
        end
      end

      def render_button_content
        if @action.icon
          render @action.icon.new(class: icon_classes)
        end
        span { @action.label }
      end

      def button_classes
        tokens(
          base_classes,
          color_classes,
          size_classes,
          -> { @action.icon && @variant != :table } => "space-x-1"
        )
      end

      def base_classes
        if @variant == :table
          "inline-flex items-center justify-center py-1 px-2 rounded-lg focus:outline-none focus:ring-2"
        else
          "flex items-center justify-center px-4 py-2 text-sm font-medium rounded-lg focus:outline-none focus:ring-4"
        end
      end

      def icon_classes
        if @variant == :table
          "h-4 w-4 mr-1"
        else
          "h-3.5 w-3.5 -ml-1"
        end
      end

      def size_classes
        (@variant == :table) ? "text-xs" : "text-sm"
      end

      def color_classes
        case @action.color || @action.category.to_sym
        when :primary
          variant_class(
            "bg-primary-700 text-white hover:bg-primary-800 focus:ring-primary-300 dark:bg-primary-600 dark:hover:bg-primary-700 dark:focus:ring-primary-800",
            table: "bg-primary-100 text-primary-700 hover:bg-primary-200 focus:ring-primary-300 dark:bg-primary-700 dark:text-primary-100 dark:hover:bg-primary-600 dark:focus:ring-primary-600"
          )
        when :success
          variant_class(
            "bg-success-700 text-white hover:bg-success-800 focus:ring-success-300 dark:bg-success-600 dark:hover:bg-success-700 dark:focus:ring-success-800",
            table: "bg-success-100 text-success-700 hover:bg-success-200 focus:ring-success-300 dark:bg-success-700 dark:text-success-100 dark:hover:bg-success-600 dark:focus:ring-success-600"
          )
        when :info
          variant_class(
            "bg-info-700 text-white hover:bg-info-800 focus:ring-info-300 dark:bg-info-600 dark:hover:bg-info-700 dark:focus:ring-info-800",
            table: "bg-info-100 text-info-700 hover:bg-info-200 focus:ring-info-300 dark:bg-info-700 dark:text-info-100 dark:hover:bg-info-600 dark:focus:ring-info-600"
          )
        when :warning
          variant_class(
            "bg-warning-700 text-white hover:bg-warning-800 focus:ring-warning-300 dark:bg-warning-600 dark:hover:bg-warning-700 dark:focus:ring-warning-800",
            table: "bg-warning-100 text-warning-700 hover:bg-warning-200 focus:ring-warning-300 dark:bg-warning-700 dark:text-warning-100 dark:hover:bg-warning-600 dark:focus:ring-warning-600"
          )
        when :danger
          variant_class(
            "bg-danger-700 text-white hover:bg-danger-800 focus:ring-danger-300 dark:bg-danger-600 dark:hover:bg-danger-700 dark:focus:ring-danger-800",
            table: "bg-danger-100 text-danger-700 hover:bg-danger-200 focus:ring-danger-300 dark:bg-danger-700 dark:text-danger-100 dark:hover:bg-danger-600 dark:focus:ring-danger-600"
          )
        when :accent
          variant_class(
            "bg-accent-700 text-white hover:bg-accent-800 focus:ring-accent-300 dark:bg-accent-600 dark:hover:bg-accent-700 dark:focus:ring-accent-800",
            table: "bg-accent-100 text-accent-700 hover:bg-accent-200 focus:ring-accent-300 dark:bg-accent-700 dark:text-accent-100 dark:hover:bg-accent-600 dark:focus:ring-accent-600"
          )
        else
          variant_class(
            "bg-secondary-700 text-white hover:bg-secondary-800 focus:ring-secondary-300 dark:bg-secondary-600 dark:hover:bg-secondary-700 dark:focus:ring-secondary-800",
            table: "bg-secondary-100 text-secondary-700 hover:bg-secondary-200 focus:ring-secondary-300 dark:bg-secondary-700 dark:text-secondary-100 dark:hover:bg-secondary-600 dark:focus:ring-secondary-600"
          )
        end
      end

      def variant_class(default, table:)
        case @variant
        when :table
          table
        else
          default
        end
      end
    end
  end
end
