# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # The {Plutonium::Query::Filters::Tags} input. Offers only the tags on
        # records the user can see (the policy scope), so a tenant never sees
        # another tenant's vocabulary and every option matches something.
        class TagsFilter < List
          include Plutonium::UI::Component::Methods

          protected

          def build_attributes
            @context = attributes.delete(:context)
            attributes[:addable] = false
            attributes[:data_controller] = tokens(attributes[:data_controller], "slim-select")
            attributes[:class] = ""
            super
          end

          # Built at render time: the policy scope needs the view context,
          # which doesn't exist yet when attributes are built.
          def choices
            @choices ||= build_choice_mapper(current_values | visible_tags)
          end

          private

          def visible_tags
            tag_class = Plutonium::UI::Options::TagsField.context(resource_class.new, @context)[:tag_class_name].constantize
            name = tag_class.arel_table[:name]
            authorized_resource_scope(resource_class).unscope(:order, :select).joins(@context).distinct.order(name).pluck(name)
          end
        end
      end
    end
  end
end
