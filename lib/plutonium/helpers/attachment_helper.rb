module Plutonium
  module Helpers
    module AttachmentHelper
      def attachment_preview(attachments, **options)
        clamp_content begin
          tag.div class: [options[:identity_class], "attachment-preview-container d-flex flex-wrap gap-1 my-1"],
            data: {controller: "attachment-preview-container"} do
            Array(attachments).each do |attachment|
              next unless attachment.url.present?

              concat begin
                tag.div class: [options[:identity_class], "attachment-preview d-inline-block text-center"],
                  title: attachment.filename,
                  data: {
                    controller: "attachment-preview",
                    attachment_preview_mime_type_value: attachment.content_type,
                    attachment_preview_thumbnail_url_value: _attachment_thumbnail_url(attachment)
                  } do
                  tag.figure class: "figure my-1", style: "width: 160px;" do
                    concat attachment_preview_thumnail(attachment)
                    concat begin
                      tag.figcaption class: "figure-caption text-truncate" do
                        if options[:caption]
                          caption = options[:caption].is_a?(String) ? options[:caption] : attachment.filename
                          concat link_to(caption, attachment.url, class: "text-decoration-none", target: :blank)
                        end

                        if block_given?
                          elements = Array(yield attachment).compact
                          elements.each { |elem| concat elem }
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      def attachment_preview_thumnail(attachment)
        return unless attachment.url.present?

        # Any changes made here must be reflected in attachment_input_controller#buildPreviewTemplate

        tag.div class: "bg-white border border-gray-200 rounded-lg shadow hover:bg-gray-100 dark:bg-gray-800 dark:border-gray-700 dark:hover:bg-gray-700", data: {attachment_preview_target: "thumbnail"} do
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
