module Plutonium
  module Helpers
    module AttachmentHelper
      def attachment_preview(attachments, **options)
        clamp_content begin
          tag.div class: [options[:identity_class], "attachment-preview-container d-flex flex-wrap gap-1 my-1"],
            data: {controller: "attachment-preview-container"} do
            Array(attachments).each do |attachment|
              next unless attachment.file.present?

              concat begin
                tag.div class: [options[:identity_class], "attachment-preview d-inline-block text-center"],
                  title: attachment.file.original_filename,
                  data: {
                    controller: "attachment-preview",
                    attachment_preview_mime_type_value: attachment.file.mime_type,
                    attachment_preview_thumbnail_url_value: attachment.thumbnail_url
                  } do
                  tag.figure class: "figure my-1", style: "width: 160px;" do
                    concat attachment_preview_thumnail(attachment)
                    concat begin
                      tag.figcaption class: "figure-caption text-truncate" do
                        if options[:caption]
                          caption = options[:caption].is_a?(String) ? options[:caption] : attachment.file.original_filename
                          concat link_to(caption, attachment.file_url, class: "text-decoration-none", target: :blank)
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
        return unless attachment.file.present?

        # Any changes made here must be reflected in attachment_input_controller#buildPreviewTemplate

        tag.div class: "d-inline-block img-thumbnail", data: {attachment_preview_target: "thumbnail"} do
          link_body = if attachment.representable?
            image_tag attachment.thumbnail_url, style: "width:100%; height:100%; object-fit: contain;"
          else
            "#{attachment.file.extension}"
          end

          link_to link_body, attachment.file_url, style: "width:150px; height:150px; line-height: 150px;",
            class: "d-block text-decoration-none user-select-none fs-5 font-monospace text-body-secondary",
            target: :blank,
            data: {attachment_preview_target: "thumbnailLink"}
        end
      end
    end
  end
end
