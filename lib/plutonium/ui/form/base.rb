# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Base < Phlexi::Form::Base
        include Plutonium::UI::Component::Behaviour

        class Builder < Builder
          include Plutonium::UI::Form::Options::InferredTypes

          def easymde_tag(**, &)
            create_component(Plutonium::UI::Form::Components::EasymdeInput, :easymde, **, &)
          end
          alias_method :markdown_tag, :easymde_tag

          alias_method :basic_select_tag, :select_tag
          def slim_select_tag(**, &)
            basic_select_tag(**, data_controller: "slim-select", class!: "", &)
          end
          alias_method :select_tag, :slim_select_tag

          def flatpickr_tag(**, &)
            create_component(Plutonium::UI::Form::Components::FlatpickrInput, :flatpickr, **, &)
          end
        end

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
