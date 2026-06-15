# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Renders a form section's chrome (heading/description, optional native
        # <details> collapsible, and a fields grid) and yields to a block that
        # renders the section's fields (the form supplies render_resource_field).
        class Section < Plutonium::UI::Component::Base
          def initialize(resolved, grid_class:)
            @section = resolved.section
            @grid_class = grid_class
          end

          SECTION_CLASS = "space-y-5 pt-7 first:pt-0"
          # A short primary accent rule to the left of the heading — anchors the
          # section and adds a touch of brand. Shared by the grouped <div> header
          # and the collapsible <summary> so both read the same.
          ACCENT_CLASS = "border-l-[3px] border-primary-500 pl-3.5"
          HEADING_CLASS = "text-base font-semibold tracking-tight text-[var(--pu-text)]"
          SUMMARY_CLASS = "#{HEADING_CLASS} #{ACCENT_CLASS} cursor-pointer select-none"
          # font-normal resets the semibold inherited from a <summary> parent.
          DESCRIPTION_CLASS = "mt-1 text-sm font-normal text-[var(--pu-text-muted)]"

          def view_template(&fields_block)
            if @section.collapsible?
              details(open: !@section.collapsed?, class: SECTION_CLASS) do
                # <summary> must be the first child of <details> and can't be
                # wrapped, so the title text and its description both live inside
                # it — keeping the description hugging the title under one accent.
                summary(class: SUMMARY_CLASS) do
                  plain heading_text
                  describe
                end
                grid(&fields_block)
              end
            else
              div(class: SECTION_CLASS) do
                header_block
                grid(&fields_block)
              end
            end
          end

          private

          # Title + description grouped under one accented header so the
          # description hugs the heading (mt-1) instead of inheriting the
          # section's larger vertical rhythm.
          def header_block
            return if @section.ungrouped? && @section.options[:label].nil?
            div(class: ACCENT_CLASS) do
              h3(class: HEADING_CLASS) { heading_text }
              describe
            end
          end

          def heading_text = @section.label

          def describe
            return unless @section.description
            p(class: DESCRIPTION_CLASS) { @section.description }
          end

          def grid(&fields_block)
            div(class: @grid_class, &fields_block)
          end
        end
      end
    end
  end
end
