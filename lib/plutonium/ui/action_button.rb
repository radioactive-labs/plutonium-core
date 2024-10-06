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
        link_to(
          @url,
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
          "h-3.5 w-3.5 mr-2 -ml-1"
        end
      end

      def size_classes
        (@variant == :table) ? "text-xs" : "text-sm"
      end

      def color_classes
        case @action.color || @action.category.to_sym
        when :primary
          table_variant_class(
            "bg-primary-100 text-primary-700 hover:bg-primary-200 focus:ring-primary-300 dark:bg-primary-700 dark:text-primary-100 dark:hover:bg-primary-600 dark:focus:ring-primary-600",
            "bg-primary-700 text-white hover:bg-primary-800 focus:ring-primary-300 dark:bg-primary-600 dark:hover:bg-primary-700 dark:focus:ring-primary-800"
          )
        when :warning
          table_variant_class(
            "bg-yellow-100 text-yellow-700 hover:bg-yellow-200 focus:ring-yellow-300 dark:bg-yellow-700 dark:text-yellow-100 dark:hover:bg-yellow-600 dark:focus:ring-yellow-600",
            "bg-yellow-400 text-white hover:bg-yellow-500 focus:ring-yellow-300 dark:bg-yellow-600 dark:hover:bg-yellow-700 dark:focus:ring-yellow-800"
          )
        when :danger
          table_variant_class(
            "bg-red-100 text-red-700 hover:bg-red-200 focus:ring-red-300 dark:bg-red-700 dark:text-red-100 dark:hover:bg-red-600 dark:focus:ring-red-600",
            "bg-red-700 text-white hover:bg-red-800 focus:ring-red-300 dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-900"
          )
        when :success
          table_variant_class(
            "bg-green-100 text-green-700 hover:bg-green-200 focus:ring-green-300 dark:bg-green-700 dark:text-green-100 dark:hover:bg-green-600 dark:focus:ring-green-600",
            "bg-green-700 text-white hover:bg-green-800 focus:ring-green-300 dark:bg-green-600 dark:hover:bg-green-700 dark:focus:ring-green-800"
          )
        else
          table_variant_class(
            "bg-gray-100 text-gray-700 hover:bg-gray-200 focus:ring-gray-300 dark:bg-gray-700 dark:text-gray-100 dark:hover:bg-gray-600 dark:focus:ring-gray-600",
            "border border-gray-200 bg-white text-gray-900 hover:bg-gray-100 hover:text-primary-700 focus:z-10 focus:ring-gray-100 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700 dark:hover:text-white dark:focus:ring-gray-700"
          )
        end
      end

      def table_variant_class(table_class, default_class)
        (@variant == :table) ? table_class : default_class
      end
    end
  end
end
