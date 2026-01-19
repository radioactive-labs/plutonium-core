# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Base < Phlexi::Display::Base
        include Plutonium::UI::Component::Behaviour

        class Builder < Builder
          include Plutonium::UI::Display::Options::InferredTypes

          def association_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Association, :association, **, &)
          end

          def markdown_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Markdown, :markdown, **, &)
          end
          alias_method :rich_text_tag, :markdown_tag

          def attachment_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Attachment, :attachment, **, &)
          end

          def phlexi_render_tag(**, &)
            create_component(Plutonium::UI::Display::Components::PhlexiRender, :phlexi_render, **, &)
          end

          def boolean_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Boolean, :boolean, **, &)
          end

          def color_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Color, :color, **, &)
          end

          # Type aliases for common column types
          alias_method :float_tag, :number_tag
          alias_method :decimal_tag, :number_tag
          alias_method :jsonb_tag, :json_tag
          alias_method :key_value_tag, :hstore_tag
          alias_method :phlexi_tag, :phlexi_render_tag
        end

        private

        def fields_wrapper(&)
          div(class: themed(:fields_wrapper)) {
            yield
          }
        end
      end
    end
  end
end
