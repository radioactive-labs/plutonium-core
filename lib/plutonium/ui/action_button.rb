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

      # Color to CSS class mapping for dropdown item variants
      DROPDOWN_COLOR_CLASSES = {
        danger: "text-danger-600 dark:text-danger-400 hover:bg-danger-50 dark:hover:bg-danger-900/30"
      }.freeze

      DROPDOWN_DEFAULT_COLOR = "text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"

      def initialize(action, url:, variant: :default)
        @action = action
        @url = url
        @variant = variant
      end

      def view_template
        case @variant
        when :dropdown, :row_dropdown
          render_dropdown_item
        else
          if @action.route_options.method == :get
            render_link
          else
            render_button
          end
        end
      end

      private

      def render_link
        link_to(
          url_with_return_to,
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
          name: :return_to, value: return_to_url,
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

      def render_dropdown_item
        link_attrs = {
          href: url_with_return_to,
          class: dropdown_item_classes
        }

        # Add turbo frame if specified
        link_attrs[:data] = {turbo_frame: @action.turbo_frame} if @action.turbo_frame

        # Add confirmation and method for non-GET requests
        if @action.confirmation || @action.route_options.method != :get
          link_attrs[:data] ||= {}
          link_attrs[:data][:turbo_method] = @action.route_options.method if @action.route_options.method != :get
          link_attrs[:data][:turbo_confirm] = @action.confirmation if @action.confirmation
        end

        a(**link_attrs) do
          render @action.icon.new(class: "w-4 h-4") if @action.icon
          span { @action.label }
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

      def dropdown_item_classes
        base_classes = "flex items-center gap-2 text-sm transition-colors"
        size_classes = (@variant == :row_dropdown) ? "px-3 py-1.5" : "px-4 py-2"

        # Use same color determination as buttons: color || category
        color_key = (@action.color || @action.category)&.to_sym
        color_classes = DROPDOWN_COLOR_CLASSES[color_key] || DROPDOWN_DEFAULT_COLOR

        "#{base_classes} #{size_classes} #{color_classes}"
      end

      def url_with_return_to
        uri = URI.parse(@url)
        params = Rack::Utils.parse_nested_query(uri.query)
        params["return_to"] = return_to_url
        uri.query = params.to_query
        uri.to_s
      end

      def default_return_to
        # When in a turbo frame with a parent, return to parent's show page
        # instead of the frame's URL (which would be the nested index)
        if current_turbo_frame && current_parent
          resource_url_for(current_parent, parent: nil)
        else
          request.original_url
        end
      end

      def return_to_url
        @action.return_to.nil? ? default_return_to : @action.return_to
      end
    end
  end
end
