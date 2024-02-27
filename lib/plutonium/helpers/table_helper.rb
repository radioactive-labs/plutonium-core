module Plutonium
  module Helpers
    module TableHelper
      def table_header(name, label, search_object)
        if (sort_params = search_object.sort_params_for(name))
          tag.span do
            concat begin
              link_to(sort_params[:url], class: "text-decoration-none") do
                concat label
                if sort_params[:direction].present?
                  icon = (sort_params[:direction] == "ASC") ? "up" : "down"
                  concat " "
                  concat tag.i(class: "bi bi-sort-#{icon} text-muted", title: sort_params[:direction])
                end
              end
            end
            if sort_params[:position].present?
              concat " "
              concat link_to(sort_params[:position], sort_params[:reset_url],
                class: "badge rounded-pill text-bg-secondary text-decoration-none", title: "remove sorting",
                style: "font-size: 0.6em;")
            end
          end
        else
          label
        end
      end

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
