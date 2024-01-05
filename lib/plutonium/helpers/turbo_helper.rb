module Plutonium
  module Helpers
    module TurboHelper
      def current_turbo_frame
        request.headers["Turbo-Frame"]
      end

      def modal_frame_tag(&block)
        turbo_frame_tag "modal", &block
      end
    end
  end
end
