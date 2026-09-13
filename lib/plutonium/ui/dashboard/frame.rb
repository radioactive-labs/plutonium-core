# frozen_string_literal: true

module Plutonium
  module UI
    module Dashboard
      # What the card endpoint renders: the card inside the turbo frame the
      # board is waiting on. Wrapped unconditionally, so a direct visit to the
      # card URL shows the same card inside the full layout.
      class Frame < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::TurboFrameTag

        def initialize(dashboard:, card:)
          @dashboard = dashboard
          @card = card
        end

        def view_template
          turbo_frame_tag(@card.frame_id, class: "block") do
            render Card.for(dashboard: @dashboard, card: @card)
          end
        end
      end
    end
  end
end
