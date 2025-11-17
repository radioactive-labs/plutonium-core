# frozen_string_literal: true

module Plutonium
  module UI
    module Component
      # Provides custom CSS class names for Plutonium UI components
      # to enable CSS-based theming without overriding components
      #
      # Users can customize via:
      # 1. Tailwind config (for ALL design tokens - radius, shadows, spacing, colors, etc.)
      # 2. CSS overrides using custom classes (e.g., .pu-button, .pu-card)
      #
      # @example Customizing via Tailwind config
      #   // tailwind.config.js
      #   module.exports = {
      #     theme: {
      #       extend: {
      #         borderRadius: {
      #           'lg': '1rem',  // Makes all rounded-sm bigger
      #         },
      #         boxShadow: {
      #           'md': '0 8px 16px rgba(0,0,0,0.1)',  // Customize shadow-md
      #         }
      #       }
      #     }
      #   }
      #
      # @example Customizing specific components via CSS
      #   .pu-button {
      #     text-transform: uppercase;
      #   }
      #
      #   .pu-card {
      #     border-radius: 0; /* Sharp corners only on cards */
      #   }
      #
      module Theme
        # Custom class names for CSS targeting
        # Format: pu-{component}[-{variant}][-{element}]
        def self.custom_class(component, variant: nil, element: nil)
          parts = ["pu", component, variant, element].compact
          parts.join("-")
        end
      end
    end
  end
end
