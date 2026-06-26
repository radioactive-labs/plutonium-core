# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Base < Phlexi::Form::Base
        include Plutonium::UI::Component::Behaviour

        class Builder < Builder
          include Phlexi::Field::Common::Tokens
          include Plutonium::UI::Form::Options::InferredTypes

          # Consume `:as` here so it doesn't land in Phlexi's `@options` —
          # `:as` is a Plutonium-internal concept (it picks the tag method),
          # not a Phlexi field option.
          def initialize(*args, as: nil, **kwargs, &block)
            @as = as
            super(*args, **kwargs, &block)
          end

          attr_reader :as

          def hidden?
            as.to_s == "hidden"
          end

          # Hidden fields (`form.field(name, as: :hidden)`) skip the label /
          # hint / error chrome and render inside a `<div hidden>` so they're
          # also excluded from CSS Grid / Flex layout.
          def wrapped(**, &)
            return Plutonium::UI::Form::Components::HiddenWrapper.new(self, &) if hidden?
            super
          end

          def textarea_tag(**attributes, &)
            attributes[:data_controller] = tokens(attributes[:data_controller], "textarea-autogrow")
            super
          end

          def easymde_tag(**, &)
            create_component(Plutonium::UI::Form::Components::Easymde, :easymde, **, &)
          end
          alias_method :markdown_tag, :easymde_tag

          def toggle_tag(**, &)
            create_component(Plutonium::UI::Form::Components::Toggle, :toggle, **, &)
          end
          alias_method :switch_tag, :toggle_tag

          # Password / secret input that never renders the stored value.
          # Routed to here for both explicit `as: :password` and every field
          # inferred as a password (see Options::InferredTypes#infer_field_component).
          def password_tag(**, &)
            create_component(Components::Password, :password, **, &)
          end

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

          def key_value_store_tag(**, &)
            create_component(Components::KeyValueStore, :key_value_store, **, &)
          end

          def json_input_tag(**, &)
            create_component(Components::Json, :json, **, &)
          end

          def resource_select_tag(**attributes, &)
            attributes[:data_controller] = tokens(attributes[:data_controller], "slim-select")
            # class!: "" clears the underlying <select>'s themed classes
            # (pu-input etc.) — the visible element is slim-select's
            # generated .ss-main, so leaving Tailwind input chrome on the
            # native select can leak into chip layout (e.g. forcing
            # flex-direction: column or w-full on multi-mode chips).
            create_component(Components::ResourceSelect, :select, class!: "", **attributes, &)
          end

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

          # Type aliases for common column types that map to different input types
          alias_method :integer_tag, :number_tag
          alias_method :float_tag, :number_tag
          alias_method :decimal_tag, :number_tag
          alias_method :text_tag, :textarea_tag
          alias_method :datetime_tag, :flatpickr_tag
          alias_method :date_tag, :flatpickr_tag
          alias_method :time_tag, :flatpickr_tag
          alias_method :rich_text_tag, :markdown_tag
          alias_method :json_tag, :json_input_tag
          alias_method :jsonb_tag, :json_input_tag
          alias_method :hstore_tag, :key_value_store_tag
          alias_method :key_value_tag, :key_value_store_tag
          alias_method :association_tag, :secure_association_tag
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
          return @form_action unless object.present? && @form_action != false && view_context.present?

          @form_action ||= url_for(object, action: object.new_record? ? :create : :update)
        end

        def initialize_attributes
          super

          # Only fall back to :resource_form when the caller didn't already
          # name the form. Phlexi moves an explicit `attributes[:id]` onto
          # `@dom_id` before this runs, so a blind `||=` here would clobber
          # things like the filter slideover's `id: "filter-form"` —
          # producing two `<form id="resource-form">` on the page and
          # silently breaking the modal pre_submit re-render (Turbo's
          # `getElementById` finds the filter form first).
          attributes[:id] ||= "resource-form" if @dom_id.nil?
          attributes["data-controller"] = form_data_controller
        end

        # `dirty-form-guard` is attached unconditionally — it self-disables
        # outside a <dialog>. Branching on `in_modal?` here would fail:
        # Phlex forbids view-context access before rendering begins.
        def form_data_controller
          "form dirty-form-guard"
        end

        # Scope the form id to the current turbo frame at render time (we
        # can't do this in `initialize_attributes` — Phlex hasn't started
        # rendering yet, so `view_context` and the request headers aren't
        # accessible). Primary and secondary modals can each host a form
        # without colliding on document-level turbo-stream `replace target=`
        # lookups. See Helpers::TurboHelper#turbo_scoped_dom_id.
        #
        # Also force-replace the id (Phlexi's `mix` would otherwise prepend
        # `@namespace.dom_id`, producing space-separated ids like
        # "q filter-form" which break document.getElementById lookups).
        def form_attributes
          attrs = super
          attrs[:id] = turbo_scoped_dom_id(attributes[:id]) if attributes[:id]
          attrs
        end
      end
    end
  end
end
