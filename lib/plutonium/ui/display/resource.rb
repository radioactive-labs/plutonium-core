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
          Block do
            fields_wrapper do
              resource_fields.each do |name|
                render_resource_field name
              end
            end
          end
        end

        def render_associations
          return unless resource_associations.present?

          tablist = BuildTabList()

          resource_associations.each do |name|
            reflection = object.class.reflect_on_association name

            if !reflection
              raise ArgumentError,
                "unknown association #{object.class}##{name} defined in #permitted_associations"
            elsif !registered_resources.include?(reflection.klass)
              raise ArgumentError,
                "#{object.class}##{name} defined in #permitted_associations, but #{reflection.klass} is not a registered resource"
            end

            title = object.class.human_attribute_name(name)
            src = case reflection.macro
            when :belongs_to, :has_one
              associated = object.public_send name
              resource_url_for(associated, parent: nil) if associated
            when :has_many
              resource_url_for(reflection.klass, parent: object)
            end

            next unless src

            tablist.with_tab(
              identifier: title.parameterize,
              title: -> { h5(class: "text-2xl font-bold tracking-tight text-gray-900 dark:text-white") { title } }
            ) do
              FrameNavigatorPanel(title: "", src:)
            end
          end

          render tablist
        end

        def render_resource_field(name)
          when_permitted(name) do
            # field :name, as: :string
            # display :name, as: :string
            # display :description, wrapper: {class: "col-span-full"}
            # display :age, class: "max-h-fit"
            # display :dob do |f|
            #   f.date_tag
            # end

            field_options = resource_definition.defined_fields[name] ? resource_definition.defined_fields[name][:options] : {}

            display_definition = resource_definition.defined_displays[name] || {}
            display_options = display_definition[:options] || {}

            tag = display_options[:as] || field_options[:as]
            tag_attributes = display_options.except(:wrapper, :as)
            tag_block = display_definition[:block] || ->(f) {
              tag ||= f.inferred_field_component
              f.send(:"#{tag}_tag", **tag_attributes)
            }

            wrapper_options = display_options[:wrapper] || {}

            field_options = field_options.except(:as)
            render field(name, **field_options).wrapped(**wrapper_options) do |f|
              render instance_exec(f, &tag_block)
            end
          end
        end

        def when_permitted(name, &)
          return unless @resource_fields.include? name

          yield
        end

        def present_associations?
          current_turbo_frame.nil?
        end
      end
    end
  end
end
