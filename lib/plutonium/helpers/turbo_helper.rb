module Plutonium
  module Helpers
    module TurboHelper
      def current_turbo_frame
        request.headers["Turbo-Frame"]
      end

      def remote_modal_frame_tag(&)
        turbo_frame_tag(Plutonium::REMOTE_MODAL_FRAME, &)
      end
    end
  end
end
