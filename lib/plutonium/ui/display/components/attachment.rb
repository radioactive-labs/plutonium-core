# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        class Attachment < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue
          include Plutonium::UI::Component::Methods
          include Plutonium::UI::Component::Behaviour

          def render_value(value)
            return unless value.url.present?

            div(
              class: "p-2 w-full",
              title: value.filename,
              data: {
                controller: "attachment-preview",
                attachment_preview_mime_type_value: value.content_type,
                attachment_preview_thumbnail_url_value: attachment_thumbnail_url(value)
              }
            ) do
              div(class: "flex flex-col items-center w-full") do
                render_thumbnail(value)
                render_caption(value)
              end
            end
          end

          private

          def render_thumbnail(attachment)
            return unless attachment.url.present?

            div(
              class: "w-full aspect-square bg-white border border-gray-200 rounded-lg shadow hover:bg-gray-50 dark:bg-gray-800 dark:border-gray-700 dark:hover:bg-gray-700 transition-all duration-300",
              data: {attachment_preview_target: "thumbnail"}
            ) do
              a(
                href: attachment.url,
                class: "block aspect-square overflow-hidden rounded-lg",
                target: :blank,
                data: {attachment_preview_target: "thumbnailLink"}
              ) do
                thumbnail_url = attachment_thumbnail_url(attachment)
                if thumbnail_url
                  img(
                    src: thumbnail_url,
                    class: "w-full h-full object-cover"
                  )
                else
                  div(class: "w-full h-full flex items-center justify-center text-gray-500 dark:text-gray-400 font-mono") do
                    ".#{attachment_extension(attachment)}"
                  end
                end
              end
            end
          end

          def render_caption(attachment)
            return if attributes[:caption] == false

            div(class: "w-full p-2 text-sm text-gray-700 dark:text-gray-300 truncate text-center") do
              caption = attributes[:caption] || attachment.filename
              a(
                href: attachment.url,
                class: "hover:text-primary-600 dark:hover:text-primary-500 transition-colors duration-200",
                target: :blank
              ) do
                phlexi_render(caption) {
                  plain caption
                }
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
