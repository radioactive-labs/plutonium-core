# frozen_string_literal: true

require "phlexi-form"

module Plutonium
  module UI
    module Display
      class Theme
        include Phlexi::Field::Theme

        THEME = {
          label: "text-base font-bold text-gray-500 dark:text-gray-400 mb-1",
          description: "text-sm text-gray-400 dark:text-gray-500",
          placeholder: "text-xl font-semibold text-gray-500 dark:text-gray-300 mb-1 italic",
          string: "text-xl font-semibold text-gray-900 dark:text-white mb-1"
        }.freeze

        def theme
          @theme ||= Phlexi::Display::Theme::DEFAULT_THEME.merge(THEME).freeze
        end
      end
    end
  end
end
