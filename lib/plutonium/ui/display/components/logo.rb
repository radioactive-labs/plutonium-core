# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        class Logo < Phlexi::Display::Components::Base
          include Phlex::Rails::Helpers::ImageTag

          def initialize(classname:, logos: nil)
            @classname = classname
            @logos = logos || {
              light: Plutonium.configuration.assets.logo,
              dark: Plutonium.configuration.assets.logo_dark
            }
          end

          def view_template
            div(class: "flex",
              data: {
                controller: "logo",
                action: "color-mode:changed@document->logo#updateFromEvent"
              }) do
              @logos.each do |mode, path|
                image_tag(path, class: @classname, data: {logo_target: mode})
              end
            end
          end
        end
      end
    end
  end
end
