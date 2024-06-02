module Plutonium::Ui
  class DynaFrameHostComponent < Plutonium::Ui::Base
    option :src

    private

    def base_attributes
      {
        id: SecureRandom.hex,
        src:
      }
    end
  end
end

Plutonium::ComponentRegistry.register :dyna_frame_host, to: Plutonium::Ui::DynaFrameHostComponent
