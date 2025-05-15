# frozen_string_literal: true

require "redcarpet"

module Plutonium
  module UI
    module Display
      module Components
        class Markdown < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue
          include Plutonium::UI::Component::Methods

          RENDERER = Redcarpet::Markdown.new(
            Redcarpet::Render::HTML.new(
              safe_links_only: true, with_toc_data: true, hard_wrap: true,
              link_attributes: {rel: :nofollow, target: :_blank}
            ),
            autolink: true, tables: true, no_intra_emphasis: true,
            fenced_code_blocks: true, disable_indented_code_blocks: true,
            strikethrough: true, space_after_headers: true, superscript: true,
            footnotes: true, highlight: true, underline: true
          )

          def render_value(value)
            article(**attributes) {
              raw(safe(render_markdown(value)))
            }
          end

          private

          def render_markdown(value)
            RENDERER.render(
              ActionController::Base.helpers.sanitize(
                value,
                tags: %w[strong em sub sup details summary],
                attributes: []
              )
            )
          end

          def normalize_value(value)
            if value.respond_to?(:to_plain_text)
              value.to_plain_text
            else
              value.to_s
            end
          end
        end
      end
    end
  end
end
