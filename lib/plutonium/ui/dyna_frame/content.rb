module Plutonium
  module UI
    module DynaFrame
      class Content < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::TurboFrameTag

        def initialize(content = nil)
          @content = content
        end

        def view_template
          if current_turbo_frame.present?
            # Frame request: render only the turbo-frame with content
            turbo_frame_tag(current_turbo_frame) do
              render partial("flash")
              @content&.call
            end
          else
            # Regular request: yield self so caller can call frame.render_content
            yield(self)
          end
        end

        def render_content
          @content&.call
        end
      end
    end
  end
end
