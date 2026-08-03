# frozen_string_literal: true

require "plutonium/positioning/config"

module Plutonium
  module Definition
    # Declares a resource drag-orderable. The MODEL owns how positions are
    # stored (`positioned_on :sort_order, scope: :project_id`); this only says
    # "this UI can be reordered", and never restates the column or the scope.
    #
    #   position_on                      # Mode A, follows the model's column
    #   position_on :sort_order          # Mode A, must MATCH the model's column
    #   position_on(:rank) { |move| … }  # Mode B, another gem owns the write
    #   position_on false                # Mode C, ordering off
    #
    # Mirrors kanban's `position_on` (lib/plutonium/kanban/dsl.rb) exactly, and
    # builds the same Plutonium::Positioning::Config. Deliberately the same verb
    # rather than a third one: the model says `positioned_on`, every UI layer
    # says `position_on`, and a kanban board with no `position_on` of its own
    # inherits the definition's (see Kanban::Board#position_config_for).
    module Positioning
      extend ActiveSupport::Concern

      included do
        class_attribute :defined_position_config, instance_accessor: false, default: nil

        # `attribute` defaults to nil, not :position — in Mode A the model has
        # already named its column, and assuming :position here would silently
        # order by one column while reposition! wrote another. Mode B has no
        # model contract to read, so it keeps :position as its own default.
        def self.position_on(attribute = nil, &block)
          config =
            if attribute == false
              Plutonium::Positioning::Config.disabled
            elsif block
              Plutonium::Positioning::Config.with_block(attribute || :position, block)
            else
              validate_model_is_positioned!(attribute)
              Plutonium::Positioning::Config.attribute(attribute || model_class.positioning_column)
            end

          self.defined_position_config = config
          return config if config.disabled?

          # Registering the sort is load-bearing: dragging is only permitted
          # when the collection is ordered by this attribute, so without a
          # permitted sort there is no way back out of the disabled state.
          sort config.attribute

          # Only claim default_sort while nobody has chosen one. A `default_sort`
          # written ABOVE position_on must survive exactly as one written below
          # it does — this method is otherwise the single order-dependent line in
          # a class body that is order-independent everywhere else (see
          # Board#position_config_for).
          #
          # `equal?`, not `==`: DEFAULT_SORT is a sentinel, and `default_sort
          # :id, :desc` builds a value-equal but distinct array. Comparing by
          # value would read that explicit choice as "untouched" and silently
          # overwrite it.
          #
          # NOTE this respects an inherited choice too: a base definition with
          # its own `default_sort` means every resource under it renders the grip
          # in the disabled state until the user sorts by position. That is the
          # intended precedence — the app asked for that ordering — and it is
          # documented in docs/reference/positioning.md.
          default_sort config.attribute, :asc if _default_sort.equal?(Sorting::DEFAULT_SORT)

          # Hidden: it has a POST member route (routing/mapper_extensions.rb) and
          # a `reposition?` policy predicate (resource/policy.rb), but is
          # reachable only by dragging — never rendered as a button.
          action :reposition, hidden: true

          config
        end

        # Mode A calls record.reposition! AND reads `.rebalanced?` off its
        # return, so it needs the real concern — not merely something that
        # responds to reposition!. A model that hand-rolls reposition!
        # (wrapping acts_as_list, say) would otherwise fail at drop time,
        # mid-transaction, with `NoMethodError: undefined method 'rebalanced?'`.
        #
        # This check lives HERE rather than in Config#reposition! for two
        # reasons: the house rule against defensive call-site guards, and
        # config.rb's standalone-loadability invariant — naming
        # Plutonium::Positioning::Model there would pull in the concern and
        # break the guard test in test/plutonium/positioning/config_test.rb.
        # The DSL is where the mode is chosen, so it is where the contract belongs.
        def self.validate_model_is_positioned!(attribute)
          declaration = attribute ? "position_on #{attribute.inspect}" : "position_on"

          unless model_class.include?(Plutonium::Positioning::Model)
            raise ArgumentError,
              "#{name || "definition"}: `#{declaration}` requires #{model_class} to " \
              "`include Plutonium::Positioning::Model` and declare `positioned_on`. " \
              "If another gem owns positioning for this model, use the block form " \
              "instead: position_on(#{(attribute || :position).inspect}) { |move| … }"
          end

          # Including the concern is not enough: without `positioned_on` there is
          # no before_create hook, so every row is created with a nil position and
          # the resulting order is arbitrary — the silent failure this class-load
          # check exists to prevent. positioning_column has a default and so
          # cannot answer this question; positioning_declared can.
          unless model_class.positioning_declared
            raise ArgumentError,
              "#{name || "definition"}: `#{declaration}` requires #{model_class} to declare " \
              "`positioned_on` — including Plutonium::Positioning::Model alone never " \
              "assigns a position on create, so every row would sort arbitrarily."
          end

          return if attribute.nil? || attribute.to_sym == model_class.positioning_column.to_sym

          raise ArgumentError,
            "#{name || "definition"}: `#{declaration}` contradicts #{model_class}'s " \
            "`positioned_on #{model_class.positioning_column.inspect}` — the collection would " \
            "be ordered by one column while reposition! wrote another, so dragging would " \
            "appear to do nothing. Drop the argument to follow the model, or use the block " \
            "form if another gem owns the write."
        end
        private_class_method :validate_model_is_positioned!
      end

      def defined_position_config = self.class.defined_position_config
    end
  end
end
