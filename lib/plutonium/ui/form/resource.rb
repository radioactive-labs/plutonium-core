# frozen_string_literal: true

require "phlexi-form"

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
            resource_fields.each { |name| resource_field name }
          }
        end

        def form_action
          return @form_action unless object.present? && @form_action != false && helpers.present?

          @form_action ||= resource_url_for(object, action: object.new_record? ? :create : :update)
        end

        def resource_field(name, **options)
          return unless @resource_fields.include? name

          render field(name).wrapped do |f|
            render f.send(:"#{f.inferred_component_type}_tag")
          end
        end
      end
    end
  end
end
