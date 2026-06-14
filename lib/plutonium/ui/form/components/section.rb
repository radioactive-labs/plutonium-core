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

          def view_template(&fields_block)
            if @section.collapsible?
              details(open: !@section.collapsed?, class: "pu-form-section pu-form-section-collapsible") do
                summary(class: "pu-form-section-summary") { heading_text }
                describe
                grid(&fields_block)
              end
            else
              div(class: "pu-form-section") do
                header_block
                grid(&fields_block)
              end
            end
          end

          private

          def header_block
            return if @section.ungrouped? && @section.options[:label].nil?
            h3(class: "pu-form-section-title") { heading_text }
            describe
          end

          def heading_text = @section.label

          def describe
            return unless @section.description
            p(class: "pu-form-section-description") { @section.description }
          end

          def grid(&fields_block)
            div(class: @grid_class, &fields_block)
          end
        end
      end
    end
  end
end
