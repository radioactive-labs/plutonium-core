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
          if associations_present?
            render_tablist_with_details
          else
            render_fields
          end
        end

        private

        def associations_present?
          present_associations? && resource_associations.present?
        end

        def render_fields
          Block do
            fields_wrapper do
              resource_fields.each do |name|
                render_resource_field name
              end
            end
          end
        end

        def render_tablist_with_details
          tablist = BuildTabList()

          # Build an inner display component for the Details tab.
          # It must be a standalone Phlex component so that TabList can call
          # `render(details_display)` from within its own context. Phlex propagates
          # @_state through render calls, so the inner component writes to the same
          # buffer as the outer Resource display even though self changes.
          details_display = build_details_display

          tablist.with_tab(
            identifier: "details",
            title: -> { plain "Details" }
          ) do
            render details_display
          end

          resource_associations.each do |name|
            reflection = object.class.reflect_on_association name
            raise_unknown_association(name) unless reflection
            raise_unregistered_association(name, reflection) unless registered_resources.include?(reflection.klass)

            title = object.class.human_attribute_name(name)
            src = association_src(name, reflection)
            next unless src

            tablist.with_tab(
              identifier: title.parameterize,
              title: -> { plain title }
            ) do
              FrameNavigatorPanel(title: "", src:, panel_id: "association-panel-#{title.parameterize}")
            end
          end

          render tablist
        end

        # Builds a standalone Phlex component whose sole job is to render the
        # resource fields. Having a distinct component lets TabList call
        # `render(details_display)` so that Phlex propagates its @_state correctly,
        # while avoiding the `instance_exec` context-switch problem that would
        # occur if we put `render_fields` directly inside the `with_tab` block.
        #
        # The anonymous subclass overrides `view_template` to skip the outer
        # `display_wrapper` div (which would duplicate the dom id already emitted
        # by the parent Resource display) and renders just the fields content.
        def build_details_display
          resource = self

          klass = Class.new(self.class) do
            define_method(:view_template) do
              resource.send(:render_fields)
            end
          end

          klass.new(
            object,
            resource_fields: resource_fields,
            resource_associations: [],
            resource_definition: resource_definition
          )
        end

        def association_src(name, reflection)
          case reflection.macro
          when :belongs_to
            associated = object.public_send name
            resource_url_for(associated, parent: nil) if associated
          when :has_one
            associated = object.public_send name
            resource_url_for(associated, parent: object, association: name)
          when :has_many
            resource_url_for(reflection.klass, parent: object, association: name)
          end
        end

        def raise_unknown_association(name)
          raise ArgumentError, "unknown association #{object.class}##{name} defined in #permitted_associations"
        end

        def raise_unregistered_association(name, reflection)
          raise ArgumentError, "#{object.class}##{name} defined in #permitted_associations, but #{reflection.klass} is not a registered resource"
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

            # Check for conditional rendering
            condition = display_options[:condition] || field_options[:condition]
            conditionally_hidden = condition && !instance_exec(&condition)
            return if conditionally_hidden

            tag = display_options[:as] || field_options[:as]

            # Extract field-level options from display_options and merge into field_options
            # These are Phlexi field options that should be passed to field(), not to the tag builder
            field_level_keys = [:label, :description, :placeholder]
            field_level_options = display_options.slice(*field_level_keys)
            field_options = field_options.merge(field_level_options)

            tag_attributes = display_options.except(:wrapper, :as, :condition, *field_level_keys)
            tag_block = display_definition[:block] || ->(f) {
              tag ||= f.inferred_field_component
              if tag.is_a?(Class)
                f.send :create_component, tag, tag.name.demodulize.underscore.sub(/component$/, "").to_sym
              else
                f.send(:"#{tag}_tag", **tag_attributes)
              end
            }

            wrapper_options = display_options[:wrapper] || {}

            field_options = field_options.except(:as, :condition)
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
