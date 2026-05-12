module Plutonium
  module Helpers
    module TurboHelper
      def current_turbo_frame
        request.headers["Turbo-Frame"]
      end

      # True when the request is rendered inside any turbo frame.
      def in_frame? = current_turbo_frame.present?

      # True when the request is rendered inside either modal frame
      # (primary or secondary).
      def in_modal? = Plutonium::MODAL_FRAMES.include?(current_turbo_frame)

      # True when the request is rendered inside the secondary (stacked)
      # modal frame specifically.
      def in_secondary_modal? = current_turbo_frame == Plutonium::REMOTE_MODAL_SECONDARY_FRAME

      def remote_modal_frame_tag(&)
        turbo_frame_tag(Plutonium::REMOTE_MODAL_FRAME, &)
      end
    end
  end
end
