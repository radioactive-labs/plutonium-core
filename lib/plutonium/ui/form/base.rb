# frozen_string_literal: true

require "phlexi-form"

module Plutonium
  module UI
    module Form
      class Base < Phlexi::Form::Base
        include Plutonium::UI::Component::Behaviour

        class FieldBuilder < FieldBuilder
          def default_theme
            # return super
            super.merge({
              # label themes
              label: "md:w-1/6 mt-2 block mb-2 text-sm font-medium",
              invalid_label: "text-red-700 dark:text-red-500",
              valid_label: "text-green-700 dark:text-green-500",
              neutral_label: "text-gray-700 dark:text-white",
              # input themes
              input: "w-full p-2 border rounded-md shadow-sm font-medium text-sm dark:bg-gray-700",
              invalid_input: "bg-red-50 border-red-500 dark:border-red-500 text-red-900 dark:text-red-500 placeholder-red-700 dark:placeholder-red-500 focus:ring-red-500 focus:border-red-500",
              valid_input: "bg-green-50 border-green-500 dark:border-green-500 text-green-900 dark:text-green-400 placeholder-green-700 dark:placeholder-green-500 focus:ring-green-500 focus:border-green-500",
              neutral_input: "border-gray-300 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white focus:ring-primary-500 focus:border-primary-500",
              # hint themes
              hint: "mt-2 text-sm text-gray-500 dark:text-gray-200",
              # error themes
              error: "mt-2 text-sm text-red-600 dark:text-red-500",
              # wrapper themes
              wrapper: "flex flex-col md:flex-row items-start space-y-2 md:space-y-0 md:space-x-2 mb-4",
              inner_wrapper: "md:w-5/6 w-full",
              # button themes
              button: "px-4 py-2 bg-primary-600 text-white rounded-md hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-primary-500"
            }).freeze
          end
        end

        def initialize(*, **options, &)
          options.fetch(:class) { options[:class] = "flex flex-col space-y-6 px-4 py-2" }
          super
        end

        private

        def render_actions
          actions_wrapper {
            render submit_button
          }
        end

        def fields_wrapper(&)
          div {
            yield
          }
        end

        def actions_wrapper(&)
          div(class: "flex justify-end space-x-2") {
            yield
          }
        end

        def form_action
          return @form_action unless object.present? && @form_action != false && helpers.present?

          @form_action ||= url_for(object, action: object.new_record? ? :create : :update)
        end
      end
    end
  end
end
