# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class Attachment < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue
          include Plutonium::UI::Component::Methods

          def render_value(value)
            attachment = value
            return unless attachment&.url.present?

            render_thumbnail(attachment)
          end

          private

          def render_thumbnail(attachment)
            div(
              class: "w-24 h-24 bg-white border border-gray-200 rounded-lg shadow hover:bg-gray-100 dark:bg-gray-800 dark:border-gray-700 dark:hover:bg-gray-700 transition-all duration-300",
              data: {
                controller: "attachment-preview",
                attachment_preview_mime_type_value: attachment.content_type,
                attachment_preview_thumbnail_url_value: attachment_thumbnail_url(attachment),
                attachment_preview_target: "thumbnail"
              }
            ) do
              a(
                href: attachment.url,
                class: "block aspect-square overflow-hidden rounded-lg",
                target: :blank,
                data: {
                  attachment_preview_target: "thumbnailLink"
                }
              ) do
                thumbnail_url = attachment_thumbnail_url(attachment)
                if thumbnail_url
                  img(
                    src: thumbnail_url,
                    class: "w-full h-full object-cover"
                  )
                else
                  div(
                    class: "w-full h-full flex items-center justify-center text-gray-500 dark:text-gray-400 font-mono"
                  ) do
                    ".#{attachment_extension(attachment)}"
                  end
                end
              end
            end
          end

          def attachment_thumbnail_url(attachment)
            attachment.url if attachment.representable?
          end

          def attachment_extension(attachment)
            attachment.try(:extension) || File.extname(attachment.filename.to_s)
          end

          def normalize_value(value)
            value
          end
        end
      end
    end
  end
end
