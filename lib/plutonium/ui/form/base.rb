# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Base < Phlexi::Form::Base
        include Plutonium::UI::Component::Behaviour

        class Builder < Builder
          include Plutonium::UI::Form::Options::InferredTypes

          def easymde_tag(**, &)
            create_component(Plutonium::UI::Form::Components::Easymde, :easymde, **, &)
          end
          alias_method :markdown_tag, :easymde_tag

          def slim_select_tag(**attributes, &)
            attributes[:data_controller] = tokens(attributes[:data_controller], "slim-select")
            select_tag(**attributes, class!: "", &)
          end

          def belongs_to_tag(**attributes, &)
            attributes[:data_controller] = tokens(attributes[:data_controller], "slim-select") # TODO: put this behind a config
            create_component(Components::BelongsTo, :belongs_to, **attributes, &)
          end

          def has_many_tag(**attributes, &)
            attributes[:data_controller] = tokens(attributes[:data_controller], "slim-select") # TODO: put this behind a config
            create_component(Components::HasMany, :has_many, **attributes, &)
          end

          def flatpickr_tag(**, &)
            create_component(Components::Flatpickr, :flatpickr, **, &)
          end

          def int_tel_input_tag(**, &)
            create_component(Components::IntlTelInput, :int_tel_input, **, &)
          end
          alias_method :phone_tag, :int_tel_input_tag
        end

        private

        def render_actions
          input name: :return_to, value: request.params[:return_to], type: :hidden, hidden: true

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
