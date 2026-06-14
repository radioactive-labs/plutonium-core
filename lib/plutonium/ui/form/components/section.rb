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

          SECTION_CLASS = "space-y-4 border-t border-[var(--pu-border-muted)] pt-6 first:border-t-0 first:pt-0"
          HEADING_CLASS = "text-base font-semibold text-[var(--pu-text)]"
          SUMMARY_CLASS = "#{HEADING_CLASS} cursor-pointer select-none"
          DESCRIPTION_CLASS = "text-sm text-[var(--pu-text-muted)]"

          def view_template(&fields_block)
            if @section.collapsible?
              details(open: !@section.collapsed?, class: SECTION_CLASS) do
                summary(class: SUMMARY_CLASS) { heading_text }
                describe
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

          def header_block
            return if @section.ungrouped? && @section.options[:label].nil?
            h3(class: HEADING_CLASS) { heading_text }
            describe
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
