module PlutoniumUi
  class DynaFrameHostComponent < PlutoniumUi::Base
    option :src
    option :loading

    private

    def base_attributes
      {
        id: SecureRandom.hex,
        src:,
        loading:
      }
    end
  end
end

Plutonium::ComponentRegistry.register :dyna_frame_host, to: PlutoniumUi::DynaFrameHostComponent
