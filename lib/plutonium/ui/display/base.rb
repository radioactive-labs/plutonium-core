# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Base < Phlexi::Display::Base
        include Plutonium::UI::Component::Behaviour

        class Builder < Builder
          include Plutonium::UI::Display::Options::InferredTypes
          include Plutonium::UI::Component::ResolvesTags

          def association_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Association, :association, **, &)
          end

          def markdown_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Markdown, :markdown, **, &)
          end

          def rich_text_tag(**, &)
            create_component(Plutonium::UI::Display::Components::RichText, :rich_text, **, &)
          end

          def attachment_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Attachment, :attachment, **, &)
          end

          def phlexi_render_tag(**, &)
            create_component(Plutonium::UI::Display::Components::PhlexiRender, :phlexi_render, **, &)
          end

          # Themed as :string so a formatted value looks identical to any other
          # string field (same wrapper + text-lg), just with the value passed
          # through the `formatter:` proc.
          def formatted_value_tag(**, &)
            create_component(Plutonium::UI::Display::Components::FormattedValue, :string, **, &)
          end

          def boolean_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Boolean, :boolean, **, &)
          end

          def color_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Color, :color, **, &)
          end

          def badge_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Badge, :badge, **, &)
          end
          alias_method :enum_tag, :badge_tag

          def currency_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Currency, :currency, **, &)
          end

          def number_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Number, :number, **, &)
          end

          def key_value_tag(**, &)
            create_component(Plutonium::UI::Display::Components::KeyValue, :key_value, **, &)
          end
          alias_method :hstore_tag, :key_value_tag

          def list_tag(**, &)
            create_component(Plutonium::UI::Display::Components::List, :list, **, &)
          end

          def tags_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Tags, :list, **, &)
          end

          def relative_time_tag(**, &)
            create_component(Plutonium::UI::Display::Components::RelativeTime, :relative_time, **, &)
          end

          def code_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Code, :code, **, &)
          end

          def duration_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Duration, :duration, **, &)
          end

          def file_size_tag(**, &)
            create_component(Plutonium::UI::Display::Components::FileSize, :file_size, **, &)
          end

          def progress_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Progress, :progress, **, &)
          end

          def rating_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Rating, :rating, **, &)
          end

          def binary_tag(**, &)
            create_component(Plutonium::UI::Display::Components::Binary, :binary, **, &)
          end

          # Type aliases for common column types
          alias_method :float_tag, :number_tag
          alias_method :decimal_tag, :number_tag
          alias_method :jsonb_tag, :json_tag
          alias_method :phlexi_tag, :phlexi_render_tag
          alias_method :secret_tag, :password_tag
        end

        private

        # A card (the shared {Plutonium::UI::Block} primitive) around the field
        # grid. Block owns what a card IS — surface, border, radius, shadow —
        # so callers just ask for a fields_wrapper and cannot end up with a
        # card that disagrees with the ones beside it.
        def fields_wrapper(&)
          render Plutonium::UI::Block.new(class: themed(:fields_wrapper)) {
            div(class: themed(:fields_inner)) {
              yield
            }
          }
        end
      end
    end
  end
end
