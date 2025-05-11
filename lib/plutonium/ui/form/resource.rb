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
          tag_attributes = input_options.except(:wrapper, :as, :pre_submit, :condition)
          if input_options[:pre_submit]
            tag_attributes["data-action"] = "change->form#preSubmit"
          end
          tag_block = input_definition[:block] || ->(f) do
            tag ||= f.inferred_field_component
            f.send(:"#{tag}_tag", **tag_attributes)
          end

          field_options = field_options.except(:as, :condition)

          condition = input_options[:condition] || field_options[:condition]
          conditionally_hidden = condition && !instance_exec(&condition)
          if conditionally_hidden
            # Do not render the field, but still create field
            # Phlexi form will record it without rendering it, allowing us to extract its value
            form.field(name, **field_options) do |f|
              instance_exec(f, &tag_block)
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
