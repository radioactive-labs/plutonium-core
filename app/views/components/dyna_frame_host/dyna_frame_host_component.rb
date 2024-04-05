module Plutonium::Ui
  class DynaFrameHostComponent < Plutonium::Ui::Base
    option :src

    def id
      super || SecureRandom.hex
    end
  end
end

Plutonium::ComponentRegistry.register :dyna_frame_host, to: Plutonium::Ui::DynaFrameHostComponent
