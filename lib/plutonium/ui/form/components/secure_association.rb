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
            return if @add_action == false || add_url.nil?

            a(
              href: add_url,
              class: "inline-flex items-center justify-center w-9 h-9 shrink-0 bg-[var(--pu-surface-alt)] hover:bg-[var(--pu-border)] border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] focus:ring-2 focus:ring-[var(--pu-border)] focus:outline-none text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] transition-colors"
            ) do
              render Phlex::TablerIcons::Plus.new(class: "w-4 h-4")
            end
          end

          def add_url
            @add_url ||= begin
              return unless @skip_authorization || allowed_to?(:create?, association_reflection.klass)

              url = @add_action || (registered_resources.include?(association_reflection.klass) && resource_url_for(association_reflection.klass, action: :new, parent: nil))
              return unless url

              uri = URI(url)
              uri.query = URI.encode_www_form({return_to: request.original_url})
              uri.to_s
            end
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
