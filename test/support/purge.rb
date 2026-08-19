# frozen_string_literal: true

# Wipes every row the dummy app owns, children before parents.
#
# This suite has no transactional rollback — test_helper.rb never loads
# rails/test_help — so each test has to clean up after itself or leave its rows
# for whatever runs next. Eighteen files were doing that by hand, and each got
# the order slightly different:
#
#   Organization.delete_all
#   User.delete_all
#
# Five tables carry a foreign key to organizations (blogging_posts,
# catalog_products, kitchen_sinks, organization_users, widgets) and thirteen to
# users. A teardown naming only some of them is a landmine twice over: it leaves
# the rows it forgot, AND it raises InvalidForeignKey the moment some other test
# has left one behind. Because it raises IN TEARDOWN, that test's own cleanup
# never finishes either, so one stale row cascades into every test in the file —
# which is why the suite failed in bursts of 20 to 60 depending only on the
# seed.
#
# The order here is computed from the schema's own foreign keys rather than
# written down, so adding a model cannot silently reintroduce the bug.
module Purge
  class << self
    # Every application table, ordered so that deleting them in sequence never
    # violates a foreign key.
    #
    # Memoized per process: the schema is built once by test_helper and does not
    # change under a running suite.
    #
    # @return [Array<String>]
    def order
      @order ||= topological_order
    end

    def reset! = @order = nil

    private

    IGNORED = %w[schema_migrations ar_internal_metadata].freeze

    # Kahn's algorithm over "table X references table Y", emitting referencing
    # tables first.
    #
    # A cycle would leave tables unemitted rather than looping forever; they are
    # appended at the end, which is the best that can be done without knowing
    # which edge to break — and is still correct for SQLite, where the delete
    # runs with the constraint checked per statement rather than per row.
    def topological_order
      connection = ActiveRecord::Base.connection
      tables = connection.tables - IGNORED

      # Self-referential keys are dropped: a table cannot be deleted before
      # itself, and a single DELETE clears the whole table at once anyway.
      dependencies = tables.to_h do |table|
        referenced = connection.foreign_keys(table).map(&:to_table).uniq
        [table, referenced.select { |t| tables.include?(t) && t != table }]
      end

      ordered = []
      remaining = dependencies.dup

      until remaining.empty?
        # Tables nothing left in `remaining` still points AT can go now.
        ready = remaining.keys.reject { |table| still_referenced?(table, remaining) }
        break if ready.empty?

        ordered.concat(ready.sort)
        ready.each { |table| remaining.delete(table) }
      end

      ordered + remaining.keys.sort
    end

    def still_referenced?(table, remaining)
      remaining.any? { |other, refs| other != table && refs.include?(table) }
    end
  end
end

module PurgeHelpers
  # Deletes every application row, in foreign-key-safe order.
  #
  # Prefer this to a hand-written list of models in +teardown+. See {Purge}.
  #
  # @return [void]
  def purge_data!
    connection = ActiveRecord::Base.connection
    Purge.order.each { |table| connection.delete("DELETE FROM #{connection.quote_table_name(table)}") }
  end
end

# Installed globally rather than included per file: the point is that no test
# has to remember the order, and a helper you must opt into is one more thing to
# forget. Minitest::Test as well as ActiveSupport::TestCase, because several
# suites here subclass the former directly.
ActiveSupport::TestCase.include(PurgeHelpers)
Minitest::Test.include(PurgeHelpers)

# And run after EVERY test, which is what actually makes the suite
# order-independent.
#
# Cleaning up in your own teardown only protects the tests you wrote. It does
# nothing about what ran before you — and a test asserting a global count
# (ModelsTest expects Blogging::Post.count == 2) fails on rows some other file
# left behind, which is a different bug from the same cause. Per-file teardowns
# cannot fix that between them; only a guarantee that every test starts clean
# can, and the cheapest place to make that guarantee is after each one.
#
# ~46 DELETEs against mostly-empty tables, which costs a few seconds across the
# whole suite. Order-dependent failures cost more than that to diagnose once.
module PurgeAfterEachTest
  def after_teardown
    super
    purge_data!
  end
end

ActiveSupport::TestCase.prepend(PurgeAfterEachTest)
Minitest::Test.prepend(PurgeAfterEachTest)
