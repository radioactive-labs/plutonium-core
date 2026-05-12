# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class SecureAssociation < Phlexi::Form::Components::AssociationBase
          include Plutonium::UI::Component::Methods

          DEFAULT_CHOICE_LIMIT = Plutonium::UI::Form::Components::ResourceSelect::DEFAULT_CHOICE_LIMIT

          def view_template
            div(class: "flex items-center space-x-1") do
              super
              render_add_button
            end
          end

          protected

          delegate :association_reflection, to: :field

          def render_add_button
            return if @add_action == false

            url, turbo_frame = add_url_and_frame
            return unless url

            # When the parent form is already inside a modal, route the
            # "+" to the secondary frame so the stacked dialog opens on
            # top of the original form rather than replacing it. The
            # crud controller mirrors this on success — closing the
            # secondary modal and reloading the primary so the
            # association select picks up the new record.
            if turbo_frame == Plutonium::REMOTE_MODAL_FRAME && in_modal?
              turbo_frame = Plutonium::REMOTE_MODAL_SECONDARY_FRAME
            end

            attrs = {
              href: url,
              class: "inline-flex items-center justify-center w-9 h-9 shrink-0 bg-[var(--pu-surface-alt)] hover:bg-[var(--pu-border)] border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] focus:ring-2 focus:ring-[var(--pu-border)] focus:outline-none text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] transition-colors"
            }
            attrs[:data] = {turbo_frame: turbo_frame} if turbo_frame

            a(**attrs) do
              render Phlex::TablerIcons::Plus.new(class: "w-4 h-4")
            end
          end

          # Resolves the destination for the inline "+" button alongside
          # the association select. We go through the target resource's
          # `:new` action (rather than building a URL by hand) so the
          # button inherits whatever modal/slideover frame the target
          # resource is configured for — same path table/grid use for
          # their own "New" button. A custom string `add_action:` skips
          # the frame lookup since we can't infer the target's modal
          # mode from an arbitrary URL.
          def add_url_and_frame
            klass = association_reflection.klass

            if @add_action.is_a?(String)
              return [with_return_to(@add_action), nil] if @skip_authorization || allowed_to?(:create?, klass)
              return
            end

            return unless registered_resources.include?(klass)
            action = resource_definition(klass).defined_actions[:new]
            return unless action
            return unless @skip_authorization || action.permitted_by?(policy_for(record: klass))

            url = route_options_to_url(action.route_options, klass)
            [with_return_to(url), action.turbo_frame]
          end

          def with_return_to(url)
            uri = URI(url)
            params = Rack::Utils.parse_nested_query(uri.query)
            params["return_to"] = request.original_url
            uri.query = params.to_query
            uri.to_s
          end

          def choices
            @choices ||= begin
              collection = if @raw_choices
                @raw_choices
              elsif @skip_authorization
                choices_from_association(association_reflection.klass)
              else
                authorized_resource_scope(association_reflection.klass, relation: choices_from_association(association_reflection.klass))
              end
              collection = collection.limit(@choice_limit) if @choice_limit && collection.respond_to?(:limit)
              build_choice_mapper(collection)
            end
          end

          def build_attributes
            build_association_attributes
            super
          end

          def build_association_attributes
            @skip_authorization = attributes.delete(:skip_authorization)
            @add_action = attributes.delete(:add_action)
            @choice_limit = attributes.fetch(:choice_limit) { DEFAULT_CHOICE_LIMIT }
            attributes.delete(:choice_limit)

            attributes.fetch(:value_method) { attributes[:value_method] = :to_signed_global_id }

            case association_reflection.macro
            when :belongs_to, :has_one
              build_singluar_association_attributes
            when :has_many, :has_and_belongs_to_many
              build_collection_association_attributes
            end
          end

          def build_singluar_association_attributes
            attributes.fetch(:input_param) { attributes[:input_param] = :"#{association_reflection.name}_sgid" }
          end

          def build_collection_association_attributes
            attributes.fetch(:input_param) { attributes[:input_param] = :"#{association_reflection.name.to_s.singularize}_sgids" }
            attributes[:multiple] = true
          end

          def normalize_simple_input(input_value)
            @signed_global_ids ||= choices.values.map { |choice| SignedGlobalID.parse(choice) }
            ([SignedGlobalID.parse(input_value.presence)].compact & @signed_global_ids)[0]
          end

          def selected?(option)
            case association_reflection.macro
            when :belongs_to, :has_one
              singular_field_value == SignedGlobalID.parse(option)
            when :has_many, :has_and_belongs_to_many
              collection_field_value.any? { |item| item == SignedGlobalID.parse(option) }
            end
          end

          def singular_field_value
            @singular_field_value ||= field.object.send :"#{association_reflection.name}_sgid"
          end

          def collection_field_value
            @collection_field_value ||= field.object.send :"#{association_reflection.name.to_s.singularize}_sgids"
          end
        end
      end
    end
  end
end
