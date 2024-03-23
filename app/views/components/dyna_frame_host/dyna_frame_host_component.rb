module Plutonium::UI
  class DynaFrameHostComponent < Plutonium::UI::Base
    option :src

    def id
      super || SecureRandom.hex
    end
  end
end

Plutonium::ComponentRegistry.register :dyna_frame_host, to: Plutonium::UI::DynaFrameHostComponent
