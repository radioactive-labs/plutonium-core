module Plutonium
  module Helpers
    module ContentHelper
      def timeago(date, format: :long)
        return if date.blank?

        content = I18n.l(date, format:)
        tag.time(
          content,
          title: content,
          data: {
            controller: "timeago",
            timeago_refresh_interval_value: 1000,
            timeago_include_seconds_value: true,
            timeago_add_suffix_value: true,
            timeago_datetime_value: date.iso8601
          }
        )
      end

      def read_more(content, clamp = 4)
        return if content.blank?

        # Stimulus Read More (https://www.stimulus-components.com/docs/stimulus-read-more/)
        style = "overflow: hidden; display: -webkit-box; -webkit-box-orient: vertical; " \
                "-webkit-line-clamp: var(--read-more-line-clamp, #{clamp});"

        tag.div(
          data: {
            controller: "read-more",
            read_more_more_text_value: "Read more",
            read_more_less_text_value: "Read less"
          }
        ) do
          concat tag.div(content,
            style:,
            data: {read_more_target: "content"})

          next unless content.lines.size > clamp

          concat tag.button("Read more",
            class: "btn btn-sm btn-link text-decoration-none ps-0",
            data: {action: "read-more#toggle"})
        end
      end

      def quill(content)
        return if content.blank?

        tag.div(
          content,
          class: "ql-viewer",
          data: {
            controller: "quill-viewer"
          }
        )
      end

      def clamp_content(content)
        return if content.blank?

        tag.div content, class: "clamped-content"
      end
    end
  end
end
