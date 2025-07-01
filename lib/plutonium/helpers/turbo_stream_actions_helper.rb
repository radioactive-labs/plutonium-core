module Plutonium
  module Helpers
    module TurboStreamActionsHelper
      def turbo_stream_redirect(url)
        turbo_stream_action_tag :redirect, url:
      end
    end
  end
end
