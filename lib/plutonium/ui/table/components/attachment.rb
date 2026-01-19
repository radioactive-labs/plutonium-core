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
              class: "w-24 h-24 bg-[var(--pu-surface)] border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] hover:bg-[var(--pu-surface-alt)] transition-all duration-300",
              style: "box-shadow: var(--pu-shadow-sm)",
              data: {
                controller: "attachment-preview",
                attachment_preview_mime_type_value: attachment.content_type,
                attachment_preview_thumbnail_url_value: attachment_thumbnail_url(attachment),
                attachment_preview_target: "thumbnail"
              },
              title: attachment.filename
            ) do
              a(
                href: attachment.url,
                class: "block aspect-square overflow-hidden rounded-[var(--pu-radius-md)]",
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
                    class: "w-full h-full flex items-center justify-center text-[var(--pu-text-muted)] font-mono"
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
