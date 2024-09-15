# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Resource < Base
        attr_reader :resource_fields, :resource_associations, :resource_definition

        def initialize(*, resource_fields:, resource_associations:, resource_definition:, **, &)
          super(*, **, &)
          @resource_fields = resource_fields
          @resource_associations = resource_associations
          @resource_definition = resource_definition
        end

        def display_template
          render_fields
          render_associations if present_associations?
        end

        private

        def render_fields
          fields_wrapper {
            resource_fields.each { |name|
              render_resource_field name
            }
          }
        end

        def render_associations
          nil
          # TODO
          # resource_associations.each do |name, renderer|
          #   #     <%= render renderer.with(record: details.record) %>
          # end
        end

        def render_resource_field(name)
          # display :name, as: :string
          # display :description, class: "col-span-full"
          # display :age, field: {class: "max-h-fit"}
          # display :dob do |f|
          #   f.date_tag
          # end

          when_permitted(name) do
            display_definition = resource_definition.defined_displays[name] || {}
            display_options = display_definition[:options] || {}
            display_field_as = display_options.delete(:as)

            display_field_options = display_options.delete(:field) || {}
            display_block = display_definition[:block] || ->(f) {
              display_field_as ||= f.inferred_field_component
              f.send(:"#{display_field_as}_tag", **display_field_options)
            }

            field_options = resource_definition.defined_fields[name] ? resource_definition.defined_fields[name][:options] : {}
            render field(name, **field_options).wrapped(**display_options) do |f|
              render display_block.call(f)
            end
          end
        end

        def when_permitted(name, &)
          return unless @resource_fields.include? name

          yield
        end

        def present_associations?
          current_parent.nil?
        end
      end
    end
  end
end
