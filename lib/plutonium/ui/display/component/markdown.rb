# frozen_string_literal: true

require "redcarpet"

module Plutonium
  module UI
    module Display
      module Component
        class Markdown < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          RENDERER = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)

          def render_value(value)
            article(**attributes) do
              unsafe_raw RENDERER.render(value)
            end
          end
        end
      end
    end
  end
end
