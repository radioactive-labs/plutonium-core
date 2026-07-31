# frozen_string_literal: true

require "plutonium/positioning/config"

module Plutonium
  module Definition
    # Declares a resource drag-orderable. The MODEL owns how positions are
    # stored (`positioned_on :position, scope: :project_id`); this only says
    # "this UI can be reordered", and never restates the column or the scope.
    #
    #   position_on                      # Mode A, attribute :position
    #   position_on :sort_order          # Mode A, custom attribute
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

        def self.position_on(attribute = :position, &block)
          config =
            if attribute == false
              Plutonium::Positioning::Config.disabled
            elsif block
              Plutonium::Positioning::Config.with_block(attribute, block)
            else
              validate_model_is_positioned!(attribute)
              Plutonium::Positioning::Config.attribute(attribute)
            end

          self.defined_position_config = config
          return config if config.disabled?

          # Registering the sort is load-bearing: dragging is only permitted
          # when the collection is ordered by this attribute, so without a
          # permitted sort there is no way back out of the disabled state.
          sort config.attribute
          default_sort config.attribute, :asc

          # Hidden: it has a route and a `reposition?` policy predicate, but is
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
          return if model_class.include?(Plutonium::Positioning::Model)

          raise ArgumentError,
            "#{name || "definition"}: `position_on #{attribute.inspect}` requires " \
            "#{model_class} to `include Plutonium::Positioning::Model` and declare " \
            "`positioned_on`. If another gem owns positioning for this model, " \
            "use the block form instead: position_on(#{attribute.inspect}) { |move| … }"
        end
      end

      def defined_position_config = self.class.defined_position_config
    end
  end
end
