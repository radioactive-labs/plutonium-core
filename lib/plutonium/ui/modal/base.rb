# frozen_string_literal: true

module Plutonium
  module UI
    module Modal
      class Base < Plutonium::UI::Component::Base
        include Phlex::Slotable

        slot :close
        slot :footer

        def initialize(title: nil, description: nil)
          @title = title
          @description = description
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
          raise NotImplementedError
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
