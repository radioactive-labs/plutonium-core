# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Select for choosing a resource record
        class ResourceSelect < Phlexi::Form::Components::Select
          include Plutonium::UI::Component::Methods

          # Cap on the number of records the dropdown materialises. Keeps
          # very large association tables from rendering thousands of
          # options into the page; consumers needing more should pair this
          # with a typeahead control later.
          DEFAULT_CHOICE_LIMIT = 100

          protected

          def choices
            @choices ||= begin
              collection = if @raw_choices
                @raw_choices
              elsif @association_class.nil?
                []
              else
                relation = @association_class.all
                relation = relation.limit(@choice_limit) if relation.respond_to?(:limit) && @choice_limit
                if @skip_authorization
                  relation
                else
                  authorized_resource_scope(@association_class, relation: relation)
                end
              end
              build_choice_mapper(collection)
            end
          end

          def build_attributes
            # Defaults must land BEFORE super — AcceptsChoices.build_attributes
            # consumes :value_method / :label_method off `attributes` into
            # its own ivars, so anything we set after super has no effect.
            attributes[:value_method] ||= :to_signed_global_id
            attributes[:label_method] ||= :to_label

            super

            @association_class = attributes.delete(:association_class)
            @skip_authorization = attributes.delete(:skip_authorization)
            @choice_limit = attributes.fetch(:choice_limit) { DEFAULT_CHOICE_LIMIT }
            attributes.delete(:choice_limit)
          end

          # SGIDs include a timestamp + signature, so the SGID in the URL
          # (generated when the user submitted) won't string-equal the
          # SGID we just generated for the same record. Compare by the
          # decoded model id instead, falling back to raw string equality
          # for non-SGID values (legacy URLs / explicit raw choices).
          def selected?(option)
            if attributes[:multiple]
              Array(field.value).any? { |v| same_record?(v, option) }
            else
              same_record?(field.value, option)
            end
          end

          def same_record?(a, b)
            return false if a.blank? || b.blank?
            (decode_id(a) || a.to_s) == (decode_id(b) || b.to_s)
          end

          def decode_id(value)
            SignedGlobalID.parse(value)&.model_id
          rescue
            nil
          end

          # Use include_blank string as blank option text (Phlexi default uses placeholder)
          def blank_option_text
            @include_blank.is_a?(String) ? @include_blank : super
          end
        end
      end
    end
  end
end
