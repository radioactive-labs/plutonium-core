# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class HasMany < Phlexi::Form::Components::HasMany
          include Plutonium::UI::Component::Methods

          def view_template
            div(class: "flex space-x-1") do
              super
              render_add_button
            end
          end

          private

          def add_url
            @add_url ||= begin
              return unless @skip_authorization || allowed_to?(:create?, association_reflection.klass)

              url = @add_action || resource_url_for(association_reflection.klass, action: :new, parent: nil)
              return unless url

              uri = URI(url)
              uri.query = URI.encode_www_form({return_to: request.original_url})
              uri.to_s
            end
          end

          def render_add_button
            return if @add_action == false || add_url.nil?

            a(
              href: add_url,
              class:
                "bg-gray-100 dark:bg-gray-600 dark:hover:bg-gray-700 dark:border-gray-500 hover:bg-gray-200 border border-gray-300 rounded-lg p-3 focus:ring-gray-100 dark:focus:ring-gray-700 focus:ring-2 focus:outline-none dark:text-white"
            ) do
              render Phlex::TablerIcons::Plus.new(class: "w-3 h-3")
            end
          end

          def choices
            @choices ||= begin
              collection = if @provided_choices || @skip_authorization
                @choice_collection
              else
                authorized_resource_scope(association_reflection.klass, relation: @choice_collection)
              end
              Phlexi::Form::ChoicesMapper.new(collection, label_method: @label_method, value_method: @value_method)
            end
          end

          def build_attributes
            @provided_choices = !attributes[:choices].nil?
            @skip_authorization = attributes.delete(:skip_authorization)
            @add_action = attributes.delete(:add_action)

            super
          end
        end
      end
    end
  end
end
