# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class Uppy < Phlexi::Form::Components::Input
          include Phlexi::Form::Components::Concerns::UploadsFile

          def view_template
            div(class: tokens(field.dom.id, "flex flex-col-reverse gap-2")) do
              div do
                # Hidden field for ensuring removal of esp. has_one_attached attachments
                input(type: :hidden, name: attributes[:name], multiple: attributes[:multiple], value: nil, autocomplete: "off", hidden: true)

                next if field.value.nil?

                div(
                  class: "attachment-preview-container grid grid-cols-[repeat(auto-fill,minmax(0,180px))] gap-4",
                  data_controller: "attachment-preview-container"
                ) do
                  render_existing_attachments
                end
              end

              div(class: "attachment-input") do
                input(
                  **build_direct_upload_options,
                  **attributes,
                  class: tokens(@input_class, attributes[:class])
                )
              end
            end
          end

          protected

          def build_input_attributes
            attributes[:type] = :file
            super

            @input_class = field.dom.id
            @include_hidden = attributes.delete(:include_hidden)
            # ensure we are always setting it to false
            attributes[:value] = false

            if attributes[:multiple]
              attributes[:name] = "#{attributes[:name].sub(/\[\]$/, "")}[]"
            end
          end

          private

          def render_existing_attachments
            Array(field.value).each do |attachment|
              next unless attachment&.url.present?

              render_attachment_preview(attachment)
            end
          end

          def render_attachment_preview(attachment)
            input_name = if attributes[:multiple]
              "#{attributes[:name].sub(/\[\]$/, "")}[]"
            else
              attributes[:name]
            end

            div(
              class: "attachment-preview group relative bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm hover:shadow-md transition-all duration-300",
              data: {
                controller: "attachment-preview",
                attachment_preview_mime_type_value: attachment.content_type,
                attachment_preview_thumbnail_url_value: attachment_thumbnail_url(attachment),
                attachment_preview_target: "thumbnail"
              },
              title: attachment.filename
            ) do
              # Hidden field to preserve the uploaded file
              input(type: :hidden, name: input_name, multiple: attributes[:multiple], value: attachment.signed_id, autocomplete: "off", hidden: true)

              render_preview_content(attachment)
              render_filename(attachment)
              render_delete_button
            end
          end

          def render_preview_content(attachment)
            a(
              href: attachment.url,
              class: "block aspect-square overflow-hidden rounded-t-lg",
              target: :blank,
              data: {attachment_preview_target: "thumbnailLink"}
            ) do
              if attachment_thumbnail_url(attachment)
                img(
                  src: attachment_thumbnail_url(attachment),
                  class: "w-full h-full object-cover"
                )
              else
                div(
                  class: "w-full h-full flex items-center justify-center bg-gray-50 dark:bg-gray-900 text-gray-500 dark:text-gray-400 font-mono"
                ) do
                  ".#{attachment_extension(attachment)}"
                end
              end
            end
          end

          def render_filename(attachment)
            div(
              class: "px-2 py-1.5 text-sm text-gray-700 dark:text-gray-300 border-t border-gray-200 dark:border-gray-700 truncate text-center bg-white dark:bg-gray-800",
              title: attachment.filename
            ) do
              plain attachment.filename.to_s
            end
          end

          def render_delete_button
            button(
              type: "button",
              class: "w-full py-2 px-4 text-sm text-red-600 dark:text-red-400 bg-white dark:bg-gray-800 hover:bg-red-50 dark:hover:bg-red-900/50 rounded-b-lg transition-colors duration-200 flex items-center justify-center gap-2 border-t border-gray-200 dark:border-gray-700",
              data: {action: "click->attachment-preview#remove"}
            ) do
              span(class: "bi bi-trash")
              plain "Delete"
            end
          end

          def attachment_thumbnail_url(attachment)
            attachment.url if attachment.representable?
          end

          def attachment_extension(attachment)
            attachment.try(:extension) || File.extname(attachment.filename.to_s)
          end

          def build_direct_upload_options
            return {} unless attributes[:direct_upload]

            direct_upload_options = {
              data: {
                controller: "attachment-input",
                attachment_input_identifier_value: @input_class,
                attachment_input_attachment_preview_outlet: ".#{@input_class} .attachment-preview",
                attachment_input_attachment_preview_container_outlet: ".#{@input_class} .attachment-preview-container"
              }
            }

            {
              max_file_size: nil,
              min_file_size: nil,
              max_total_size: nil,
              max_file_num: attributes.fetch(:size, field.multiple? ? field.limit : 1),
              min_file_num: nil,
              allowed_file_types: nil,
              required_meta_fields: nil
            }.each do |key, default_value|
              value = attributes.key?(key) ? attributes.delete(key) : default_value
              direct_upload_options[:data][:"attachment_input_#{key}_value"] = value
            end

            direct_upload_options
          end

          def normalize_input(input_value)
            input_value
          end
        end
      end
    end
  end
end
