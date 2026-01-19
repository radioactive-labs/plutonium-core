# frozen_string_literal: true

module Plutonium
  module UI
    class ActionButton < Plutonium::UI::Component::Base
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTo

      # Color to CSS class mapping for standard and soft button variants
      COLOR_CLASSES = {
        primary: {default: "pu-btn-primary", soft: "pu-btn-soft-primary"},
        success: {default: "pu-btn-success", soft: "pu-btn-soft-success"},
        info: {default: "pu-btn-info", soft: "pu-btn-soft-info"},
        warning: {default: "pu-btn-warning", soft: "pu-btn-soft-warning"},
        danger: {default: "pu-btn-danger", soft: "pu-btn-soft-danger"},
        accent: {default: "pu-btn-accent", soft: "pu-btn-soft-accent"},
        secondary: {default: "pu-btn-secondary", soft: "pu-btn-soft-secondary"}
      }.freeze

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
        params["return_to"] = @action.return_to.nil? ? request.original_url : @action.return_to
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
          name: :return_to, value: (@action.return_to.nil? ? request.original_url : @action.return_to),
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
          "pu-btn",
          size_class,
          color_class,
          -> { @action.icon } => "gap-1.5"
        )
      end

      def size_class
        (@variant == :table) ? "pu-btn-xs" : "pu-btn-md"
      end

      def icon_classes
        (@variant == :table) ? "h-4 w-4" : "h-3.5 w-3.5"
      end

      def color_class
        color_key = (@action.color || @action.category)&.to_sym || :secondary
        color_mapping = COLOR_CLASSES[color_key] || COLOR_CLASSES[:secondary]

        # Table variant uses soft (tinted) buttons, default uses solid buttons
        (@variant == :table) ? color_mapping[:soft] : color_mapping[:default]
      end
    end
  end
end
