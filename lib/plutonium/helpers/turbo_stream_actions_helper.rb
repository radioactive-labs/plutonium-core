module Plutonium
  module Helpers
    module TurboStreamActionsHelper
      def turbo_stream_redirect(url)
        if turbo_stream_redirect_same_page?(url)
          turbo_stream_action_tag :refresh
        else
          turbo_stream_action_tag :redirect, url:
        end
      end

      # Closes the <dialog> inside the targeted frame and empties the
      # frame. Used to dismiss a stacked modal without affecting the
      # rest of the page.
      def turbo_stream_close_frame(frame_id)
        turbo_stream_action_tag :close_frame, target: frame_id
      end

      # Reloads the targeted frame from its current src. Used to refresh
      # the primary modal after a secondary-modal action mutates data
      # the primary depends on.
      def turbo_stream_reload_frame(frame_id)
        turbo_stream_action_tag :reload_frame, target: frame_id
      end

      private

      def turbo_stream_redirect_same_page?(url)
        return false if request.referer.blank?
        turbo_stream_redirect_normalize_url(url) == turbo_stream_redirect_normalize_url(request.referer)
      end

      def turbo_stream_redirect_normalize_url(url)
        uri = URI.parse(url.to_s)
        path = uri.path.to_s.chomp("/").presence || "/"
        [path, uri.query].compact.join("?")
      rescue URI::InvalidURIError
        url.to_s
      end
    end
  end
end
