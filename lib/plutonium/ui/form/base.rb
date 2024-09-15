# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Base < Phlexi::Form::Base
        include Plutonium::UI::Component::Behaviour

        private

        def render_actions
          actions_wrapper {
            render submit_button
          }
        end

        def fields_wrapper(&)
          div(class: themed(:fields_wrapper, nil)) {
            yield
          }
        end

        def actions_wrapper(&)
          div(class: themed(:actions_wrapper, nil)) {
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
