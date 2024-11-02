module Plutonium
  module UI
    module DynaFrame
      class Host < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::TurboFrameTag

        def initialize(src:, loading:, id: SecureRandom.hex, **attributes)
          @id = id
          @src = src
          @loading = loading
          @attributes = attributes
        end

        def view_template(&)
          turbo_frame_tag(@id, src: @src, loading: @loading, **@attributes, &)
        end
      end
    end
  end
end
