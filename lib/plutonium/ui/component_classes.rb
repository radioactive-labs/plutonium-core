# frozen_string_literal: true

module Plutonium
  module UI
    # Centralized CSS class mappings for Plutonium UI components.
    # Provides reusable class constants that leverage the design token system.
    module ComponentClasses
      # Button component classes
      module Button
        BASE = "pu-btn"
        SIZE_DEFAULT = "pu-btn-md"
        SIZE_SM = "pu-btn-sm"
        SIZE_XS = "pu-btn-xs"

        VARIANTS = {
          primary: "pu-btn-primary",
          secondary: "pu-btn-secondary",
          danger: "pu-btn-danger",
          success: "pu-btn-success",
          warning: "pu-btn-warning",
          info: "pu-btn-info",
          accent: "pu-btn-accent",
          ghost: "pu-btn-ghost"
        }.freeze

        SOFT_VARIANTS = {
          primary: "pu-btn-soft-primary",
          secondary: "pu-btn-soft-secondary",
          danger: "pu-btn-soft-danger",
          success: "pu-btn-soft-success",
          warning: "pu-btn-soft-warning",
          info: "pu-btn-soft-info",
          accent: "pu-btn-soft-accent"
        }.freeze

        def self.classes(variant: :primary, size: :default, soft: false)
          variant_class = soft ? SOFT_VARIANTS[variant] : VARIANTS[variant]
          size_class = case size
          when :sm then SIZE_SM
          when :xs then SIZE_XS
          else SIZE_DEFAULT
          end
          "#{BASE} #{size_class} #{variant_class}"
        end
      end

      # Table component classes
      module Table
        WRAPPER = "pu-table-wrapper"
        BASE = "pu-table"
        HEADER = "pu-table-header"
        HEADER_CELL = "pu-table-header-cell"
        BODY_ROW = "pu-table-body-row"
        BODY_ROW_SELECTED = "pu-table-body-row-selected"
        BODY_CELL = "pu-table-body-cell"
        SELECTION_CELL = "pu-selection-cell"
        CHECKBOX = "pu-checkbox"
      end

      # Form component classes
      module Form
        WRAPPER = "pu-card"
        BODY = "pu-card-body space-y-6"
        FIELDS_WRAPPER = "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-4 grid-flow-row-dense"
        ACTIONS_WRAPPER = "flex justify-end gap-2"

        INPUT = "pu-input"
        INPUT_INVALID = "pu-input pu-input-invalid"
        INPUT_VALID = "pu-input pu-input-valid"

        LABEL = "pu-label"
        HINT = "pu-hint"
        ERROR = "pu-error"
        BUTTON = "pu-btn pu-btn-md pu-btn-primary"
      end

      # Toolbar component classes
      module Toolbar
        WRAPPER = "pu-toolbar"
        TEXT = "pu-toolbar-text"
        ACTIONS = "pu-toolbar-actions"
      end

      # Card component classes
      module Card
        BASE = "pu-card"
        BODY = "pu-card-body"
        HEADER = "pu-panel-header"
        TITLE = "pu-panel-title"
        DESCRIPTION = "pu-panel-description"
      end

      # Empty state classes
      module EmptyState
        WRAPPER = "pu-empty-state"
        ICON = "pu-empty-state-icon"
        TITLE = "pu-empty-state-title"
        DESCRIPTION = "pu-empty-state-description"
      end
    end
  end
end
