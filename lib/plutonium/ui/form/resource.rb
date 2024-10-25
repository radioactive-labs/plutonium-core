# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Resource < Base
        attr_reader :resource_fields, :resource_definition

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
          # input :name, as: :string
          # input :description, class: "col-span-full"
          # input :age, field: {class: "max-h-fit"}
          # input :dob do |f|
          #   f.date_tag
          # end

          when_permitted(name) do
            input_definition = resource_definition.defined_inputs[name] || {}
            input_options = input_definition[:options] || {}

            input_tag = input_options[:as]
            input_tag_options = input_options[:field] || {}
            input_tag_block = input_definition[:block] || ->(f) {
              input_tag ||= f.inferred_field_component
              f.send(:"#{input_tag}_tag", **input_tag_options)
            }

            field_options = resource_definition.defined_fields[name] ? resource_definition.defined_fields[name][:options] : {}
            wrapper_options = input_options.except(:field, :as)
            if !wrapper_options[:class] || wrapper_options[:class].include?("col-span")
              # temp hack to allow col span overrides
              # TODO: remove once we complete theming, which will support merges
              wrapper_options[:class] = tokens("col-span-full", wrapper_options[:class])
            end
            render field(name, **field_options).wrapped(**wrapper_options) do |f|
              render input_tag_block.call(f)
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
