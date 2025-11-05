# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Resource < Base
        include Plutonium::UI::Form::Concerns::RendersNestedResourceFields

        attr_reader :resource_fields, :resource_definition

        alias_method :record, :object

        def initialize(*, resource_fields:, resource_definition:, **, &)
          super(*, **, &)
          @resource_fields = resource_fields
          @resource_definition = resource_definition
        end

        def form_template
          render_fields
          render_actions
        end

        private

        def render_fields
          fields_wrapper {
            resource_fields.each { |name|
              render_resource_field name
            }
          }
        end

        def render_actions
          input name: "return_to", value: request.params[:return_to], type: :hidden, hidden: true

          actions_wrapper {
            if object.respond_to?(:new_record?)
              if object.new_record?
                button(
                  type: :submit,
                  name: "return_to",
                  value: request.url,
                  class: "px-4 py-2 bg-secondary-600 text-white rounded-md hover:bg-secondary-700 focus:outline-none focus:ring-2 focus:ring-secondary-500"
                ) { "Create and add another" }
              else
                button(
                  type: :submit,
                  name: "return_to",
                  value: request.url,
                  class: "px-4 py-2 bg-secondary-600 text-white rounded-md hover:bg-secondary-700 focus:outline-none focus:ring-2 focus:ring-secondary-500"
                ) { "Update and continue editing" }
              end
            end

            render submit_button
          }
        end

        def form_action
          return @form_action unless object.present? && @form_action != false && helpers.present?

          @form_action ||= resource_url_for(object, action: object.new_record? ? :create : :update)
        end

        def render_resource_field(name)
          when_permitted(name) do
            if resource_definition.respond_to?(:defined_nested_inputs) && resource_definition.defined_nested_inputs[name]
              render_nested_resource_field(name)
            else
              render_simple_resource_field(name, resource_definition, self)
            end
          end
        end

        def render_simple_resource_field(name, definition, form)
          # field :name, as: :string
          # input :name, as: :string
          # input :description, wrapper: {class: "col-span-full"}
          # input :age, class: "max-h-fit"
          # input :dob do |f|
          #   f.date_tag
          # end

          field_options = definition.defined_fields[name] ? definition.defined_fields[name][:options] : {}

          input_definition = definition.defined_inputs[name] || {}
          input_options = input_definition[:options] || {}

          tag = input_options[:as] || field_options[:as]

          # Extract field-level options from input_options and merge into field_options
          # These are Phlexi field options that should be passed to form.field(), not to the tag builder
          # Note: forms use :hint, displays use :description
          field_level_keys = [:hint, :label, :placeholder]
          field_level_options = input_options.slice(*field_level_keys)
          field_options = field_options.merge(field_level_options)

          tag_attributes = input_options.except(:wrapper, :as, :pre_submit, :condition, *field_level_keys)
          if input_options[:pre_submit]
            tag_attributes["data-action"] = "change->form#preSubmit"
          end
          tag_block = input_definition[:block] || ->(f) do
            tag ||= f.inferred_field_component
            if tag.is_a?(Class)
              f.send :create_component, tag, tag.name.demodulize.underscore.sub(/component$/, "").to_sym
            else
              f.send(:"#{tag}_tag", **tag_attributes)
            end
          end

          field_options = field_options.except(:as, :condition)

          condition = input_options[:condition] || field_options[:condition]
          conditionally_hidden = condition && !instance_exec(&condition)
          if conditionally_hidden
            # Do not render the field, but still create field
            # Phlexi form will record it without rendering it, allowing us to extract its value
            form.field(name, **field_options) do |f|
              vanish { render instance_exec(f, &tag_block) }
            end
          else
            wrapper_options = input_options[:wrapper] || {}
            if !wrapper_options[:class] || !wrapper_options[:class].include?("col-span")
              # temp hack to allow col span overrides
              # TODO: remove once we complete theming, which will support merges
              wrapper_options[:class] = tokens("col-span-full", wrapper_options[:class])
            end

            render form.field(name, **field_options).wrapped(
              **wrapper_options
            ) do |f|
              render instance_exec(f, &tag_block)
            end
          end
        end

        def when_permitted(name, &)
          return unless resource_fields.include? name

          yield
        end
      end
    end
  end
end
