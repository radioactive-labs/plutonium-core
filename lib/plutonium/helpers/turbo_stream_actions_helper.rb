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
