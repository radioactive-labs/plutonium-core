module Plutonium
  module Helpers
    module TurboHelper
      def current_turbo_frame
        request.headers["Turbo-Frame"]
      end

      def remote_modal_frame_tag(&)
        turbo_frame_tag("remote_modal", &)
      end
    end
  end
end
