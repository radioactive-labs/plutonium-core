# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Base < Phlexi::Form::Base
        include Plutonium::UI::Component::Behaviour

        class Builder < Builder
          include Phlexi::Field::Common::Tokens
          include Plutonium::UI::Form::Options::InferredTypes

          def easymde_tag(**, &)
            create_component(Plutonium::UI::Form::Components::Easymde, :easymde, **, &)
          end
          alias_method :markdown_tag, :easymde_tag

          def slim_select_tag(**attributes, &)
            attributes[:data_controller] = tokens(attributes[:data_controller], "slim-select")
            select_tag(**attributes, required: false, class!: "", &)
          end

          def flatpickr_tag(**, &)
            create_component(Components::Flatpickr, :flatpickr, **, &)
          end

          def int_tel_input_tag(**, &)
            create_component(Components::IntlTelInput, :int_tel_input, **, &)
          end
          alias_method :phone_tag, :int_tel_input_tag

          def uppy_tag(**, &)
            create_component(Components::Uppy, :uppy, **, &)
          end
          alias_method :file_tag, :uppy_tag
          alias_method :attachment_tag, :uppy_tag

          def secure_association_tag(**attributes, &)
            attributes[:data_controller] = tokens(attributes[:data_controller], "slim-select") # TODO: put this behind a config
            create_component(Components::SecureAssociation, :association, **attributes, &)
          end
          # preserve original methods with prefix
          alias_method :basic_belongs_to_tag, :belongs_to_tag
          alias_method :basic_has_many_tag, :has_many_tag
          alias_method :basic_has_one_tag, :has_one_tag
          # use new methods as defaults
          alias_method :belongs_to_tag, :secure_association_tag
          alias_method :has_many_tag, :secure_association_tag
          alias_method :has_one_tag, :secure_association_tag

          def secure_polymorphic_association_tag(**attributes, &)
            attributes[:data_controller] = tokens(attributes[:data_controller], "slim-select") # TODO: put this behind a config
            create_component(Components::SecurePolymorphicAssociation, :polymorphic_association, **attributes, &)
          end
          # preserve original methods with prefix
          alias_method :basic_polymorphic_belongs_to_tag, :polymorphic_belongs_to_tag
          # use new methods as defaults
          alias_method :polymorphic_belongs_to_tag, :secure_polymorphic_association_tag
        end

        private

        def render_actions
          input name: "return_to", value: request.params[:return_to], type: :hidden, hidden: true

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

        def initialize_attributes
          super

          attributes["data-controller"] = "form"
        end
      end
    end
  end
end
