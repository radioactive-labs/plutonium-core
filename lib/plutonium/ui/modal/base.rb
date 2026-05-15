# frozen_string_literal: true

module Plutonium
  module UI
    module Modal
      class Base < Plutonium::UI::Component::Base
        include Phlex::Slotable

        slot :close
        slot :footer

        # Sizes that all modal subclasses must implement entries for in
        # their SIZE_CLASSES table. `:auto` is content-driven (`w-fit`
        # with a viewport cap and a sensible floor) and is the only way
        # to avoid clipping forms whose natural width exceeds the
        # default. Sizes intentionally mirror Tailwind's max-w-* scale
        # so a definition that says `size: :xl` reads predictably.
        VALID_SIZES = [:sm, :md, :lg, :xl, :auto, :full].freeze

        def initialize(title: nil, description: nil, size: :md)
          @title = title
          @description = description
          @size = size
          validate_size!
        end

        def view_template(&block)
          dialog(**dialog_attributes) do
            div(class: inner_classes) do
              render_header
              render_body(&block)
              render_footer if footer_slot?
            end
          end
        end

        protected

        # Native <dialog>+showModal() handles the focus trap, Esc-to-close,
        # and focus restoration on close. We just need to label the dialog
        # so screen readers announce it on open.
        def dialog_attributes
          attrs = {
            closedby: "any",
            class: dialog_classes,
            data: {controller: "remote-modal"},
            "aria-modal": "true"
          }
          if @title
            attrs[:"aria-labelledby"] = title_id
          else
            attrs[:"aria-label"] = "Dialog"
          end
          attrs[:"aria-describedby"] = description_id if @description.present?
          attrs
        end

        def title_id
          @title_id ||= "pu-modal-title-#{SecureRandom.hex(4)}"
        end

        def description_id
          @description_id ||= "pu-modal-desc-#{SecureRandom.hex(4)}"
        end

        def dialog_classes
          "#{base_dialog_classes} #{size_classes}"
        end

        # Positioning, backdrop, transitions — everything that does
        # not vary with `size`. Width/height tokens live in
        # `size_classes` so size keys can fully replace them
        # (notably `:auto`, which needs `w-fit` instead of `w-full`).
        def base_dialog_classes
          raise NotImplementedError
        end

        def size_classes
          self.class::SIZE_CLASSES.fetch(@size)
        end

        def validate_size!
          return if VALID_SIZES.include?(@size)
          raise ArgumentError,
            "modal size must be one of #{VALID_SIZES.inspect}, got #{@size.inspect}"
        end

        def inner_classes
          "flex flex-col h-full max-h-[inherit] min-h-0"
        end

        def render_header
          div(class: "flex items-start justify-between gap-4 px-6 pt-5 pb-4 border-b border-[var(--pu-border)]") do
            div(class: "min-w-0 flex-1") do
              if @title
                h2(id: title_id, class: "text-lg font-semibold text-[var(--pu-text)] truncate") { @title }
              end
              if @description.present?
                p(id: description_id, class: "mt-1 text-sm text-[var(--pu-text-muted)]") { @description }
              end
            end
            render_close_button
          end
        end

        def render_close_button
          if close_slot?
            render close_slot
          else
            button(
              type: "button",
              class: "p-1.5 -m-1.5 text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] rounded-md transition-colors",
              data: {action: "remote-modal#close"},
              "aria-label": "Close dialog"
            ) do
              render Phlex::TablerIcons::X.new(class: "w-5 h-5")
            end
          end
        end

        def render_body(&block)
          # Body is a flex column with no padding/scroll; content owns its
          # own padding and scroll regions. This lets form-shaped content
          # split itself into a scrollable fields region and a pinned
          # action strip flush with the modal's bottom edge.
          div(class: "flex-1 min-h-0 flex flex-col overflow-hidden", &block)
        end

        def render_footer
          div(class: "flex items-center justify-end gap-2 px-6 py-4 border-t border-[var(--pu-border)]") do
            render footer_slot
          end
        end
      end
    end
  end
end
