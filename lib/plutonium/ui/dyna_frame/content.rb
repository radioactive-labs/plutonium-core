module Plutonium
  module UI
    module DynaFrame
      class Content < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::TurboFrameTag

        def view_template
          if current_turbo_frame.present?
            render turbo_frame_tag(current_turbo_frame) {
              render "flash"
              yield
            }
          else
            yield
          end
        end
      end
    end
  end
end
