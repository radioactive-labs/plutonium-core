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

        # Resolves the concrete modal class for a definition's `modal_mode`
        # symbol. Unknown / `false` modes fall back to `Slideover` so call
        # sites can stay branchless.
        def self.class_for_mode(mode)
          (mode == :centered) ? Plutonium::UI::Modal::Centered : Plutonium::UI::Modal::Slideover
        end

        def initialize(title: nil, description: nil, size: :md)
          @title = title
          @description = description
          @size = size
          validate_size!
        end

        def view_template(&block)
          dialog(**dialog_attributes) do
            div(class: panel_classes) do
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

        # The <dialog> is a transparent, transform-free, full-viewport
        # positioning container — NOT the visible surface. It must carry
        # no transform: a transformed element becomes the containing block
        # for its `position: fixed` descendants, which would trap any fixed
        # UI opened from inside the modal (uppy's upload overlay, teleported
        # dropdowns, date pickers) inside the panel's box. So the surface,
        # size, and open/close transform animation all live on the inner
        # panel; the dialog only positions and dims (::backdrop).
        def dialog_classes
          base_dialog_classes
        end

        # Container-only: full-viewport positioning + flex alignment +
        # backdrop + `group` (so the panel can read the dialog's
        # `data-open`). No surface, no size, no transform.
        def base_dialog_classes
          raise NotImplementedError
        end

        # The visible panel: surface (bg/border/radius), `size_classes`,
        # and the open/close animation — driven by the dialog's `data-open`
        # via `group-data-[open]:`. Width/height tokens live here, not on
        # the dialog, so the dialog can stay a full-viewport container.
        def panel_classes
          "#{base_panel_classes} #{size_classes}"
        end

        def base_panel_classes
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
