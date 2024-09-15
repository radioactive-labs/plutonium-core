# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Resource < Base
        attr_reader :resource_fields

        def initialize(*, resource_fields:, resource_associations:, **, &)
          super(*, **, &)
          @resource_fields = resource_fields
          @resource_associations = resource_associations
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

        def render_resource_field(name, **options)
          return unless @resource_fields.include? name

          render field(name).wrapped do |f|
            render f.send(:"#{f.inferred_field_component}_tag")
          end
        end

        def present_associations?
          current_parent.nil?
        end
      end
    end
  end
end
