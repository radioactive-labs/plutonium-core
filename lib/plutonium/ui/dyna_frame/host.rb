module Plutonium
  module UI
    module DynaFrame
      class Host < Plutonium::UI::Component::Base
        include Phlex::Rails::Helpers::TurboFrameTag

        def initialize(src:, loading:, **attributes)
          @id = attributes.delete(:id) || SecureRandom.alphanumeric(8, chars: [*"a".."z"])
          @src = src
          @loading = loading
          @attributes = attributes
        end

        def view_template(&)
          turbo_frame_tag(@id, src: @src, loading: @loading, **@attributes, class: "dyna", refresh: "morph", &)
        end
      end
    end
  end
end
