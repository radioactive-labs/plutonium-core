# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Select for choosing a resource record
        class ResourceSelect < Phlexi::Form::Components::Select
          include Plutonium::UI::Component::Methods
          include Plutonium::UI::Form::Concerns::TypeaheadAttributes

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
                authorized_relation(limit: @choice_limit)
              end
              build_choice_mapper(collection)
            end
          end

          # Builds the authorized relation for the association class, optionally
          # capped at `limit`. Shared by `choices` (with the limit) and
          # `normalize_simple_input` (without — so typeahead picks beyond the
          # rendered subset still validate).
          def authorized_relation(limit: nil)
            relation = @association_class.all
            relation = relation.limit(limit) if limit && relation.respond_to?(:limit)
            return relation if @skip_authorization
            authorized_resource_scope(@association_class, relation: relation)
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
            # Stash the typeahead option; the URL helper needs view_context
            # which only exists once we're rendering.
            @typeahead_option = attributes.delete(:typeahead)
          end

          # Phlex hook fires right before view_template runs and view_context
          # is available, so this is where we can resolve the typeahead URL
          # and inject the data attr.
          def before_template
            super
            configure_typeahead_attributes!(@typeahead_option)
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

          # AcceptsChoices.normalize_simple_input rejects any submitted
          # value that doesn't string-match an option's value. With SGIDs
          # the URL value (signed/timestamped at submit time) never
          # string-equals a freshly generated option SGID for the same
          # record, so the value gets silently dropped — no WHERE clause
          # is built and the filter behaves as if it weren't applied.
          #
          # For SGID values backed by an association class, validate against
          # the unbounded authorized relation rather than the rendered
          # `choices` (which is capped at `choice_limit` and may not include
          # records reachable via typeahead). For raw values / explicit
          # `@raw_choices`, fall back to record-equality against the rendered
          # options.
          def normalize_simple_input(input_value)
            return nil if input_value.blank?

            sgid = SignedGlobalID.parse(input_value)
            if sgid && @association_class && !@raw_choices
              return nil unless sgid.model_class <= @association_class
              return authorized_relation.exists?(id: sgid.model_id) ? input_value : nil
            end

            choices.values.find { |opt| same_record?(input_value, opt) } && input_value
          end

          # Two values point at the same record when both decode to the
          # same SGID (class + id). For explicit non-SGID `@raw_choices`,
          # both sides are plain strings and string-equality is the only
          # sensible answer. Mixed-format (one SGID, one raw) returns
          # false — no cross-format guessing.
          def same_record?(a, b)
            return false if a.blank? || b.blank?

            a_pair = decode_class_and_id(a)
            b_pair = decode_class_and_id(b)
            return a_pair == b_pair if a_pair && b_pair
            return false if a_pair || b_pair

            a.to_s == b.to_s
          end

          def decode_class_and_id(value)
            gid = SignedGlobalID.parse(value)
            gid && [gid.model_class.name, gid.model_id]
          rescue
            nil
          end

          # Use include_blank string as blank option text (Phlexi default uses placeholder)
          def blank_option_text
            @include_blank.is_a?(String) ? @include_blank : super
          end

          private

          def typeahead_target_class
            @association_class
          end

          def typeahead_kind_and_name(_typeahead_option)
            detect_typeahead_kind_and_name
          end

          # Plutonium::UI::Form::Query roots its form with `as: :q`, so
          # any field whose ancestry includes a node keyed :q is a filter
          # input. The filter name is the immediate child of that root.
          # Form inputs (new/edit) fall through to :input + the field key.
          def detect_typeahead_kind_and_name
            lineage = field.dom.lineage
            q_index = lineage.find_index { |node| node.key == :q }
            if q_index && (filter_node = lineage[q_index + 1])
              [:filter, filter_node.key]
            else
              [:input, field.key]
            end
          end
        end
      end
    end
  end
end
