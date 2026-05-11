module Plutonium
  module UI
    module DynaFrame
      # Conditionally wraps its content in a turbo-frame matching the inbound
      # request's `Turbo-Frame` header. In frame mode adds the flash partial
      # so toast/alert messages still surface inside frames; in non-frame
      # mode renders the block as-is.
      class Content < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::TurboFrameTag

        def view_template(&block)
          if current_turbo_frame.present?
            turbo_frame_tag(current_turbo_frame) do
              render partial("flash")
              yield if block_given?
            end
          elsif block_given?
            yield
          end
        end
      end
    end
  end
end
