module Plutonium
  module Helpers
    module TableHelper
      def attachment_preview_thumnail(attachment)
        return unless attachment.url.present?

        # Any changes made here must be reflected in attachment_input_controller#buildPreviewTemplate

        tag.div class: "d-inline-block img-thumbnail", data: {attachment_preview_target: "thumbnail"} do
          thumbnail_url = _attachment_thumbnail_url(attachment)
          link_body = if thumbnail_url
            image_tag thumbnail_url, style: "width:100%; height:100%; object-fit: contain;"
          else
            _attachment_extension(attachment)
          end

          link_to link_body, attachment.url, style: "width:150px; height:150px; line-height: 150px;",
            class: "d-block text-decoration-none user-select-none fs-5 font-monospace text-body-secondary",
            target: :blank,
            data: {attachment_preview_target: "thumbnailLink"}
        end
      end

      private

      def _attachment_thumbnail_url(attachment)
        attachment.url if attachment.representable?
      end

      def _attachment_extension(attachment)
        attachment.try(:extension) || File.extname(attachment.filename.to_s)
      end
    end
  end
end
