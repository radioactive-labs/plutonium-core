# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Resource < Base
        attr_reader :resource_fields

        def initialize(*, resource_fields:, **, &)
          super(*, **, &)
          @resource_fields = resource_fields
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
          # input :name, as: :string
          # input :description, class: "col-span-full"
          # input :age, field: {class: "max-h-fit"}
          # input :dob do |f|
          #   f.date_tag
          # end

          when_permitted(name) do
            input_definition = current_definition.defined_inputs[name] || {}
            input_options = input_definition[:options] || {}
            input_field_as = input_options.delete(:as)

            input_field_options = input_options.delete(:field) || {}
            input_block = input_definition[:block] || ->(f) {
              input_field_as ||= f.inferred_field_component
              f.send(:"#{input_field_as}_tag", **input_field_options)
            }

            field_options = current_definition.defined_fields[name] ? current_definition.defined_fields[name][:options] : {}
            render field(name, **field_options).wrapped(**input_options) do |f|
              render input_block.call(f)
            end
          end
        end

        def when_permitted(name, &)
          return unless @resource_fields.include? name

          yield
        end
      end
    end
  end
end
