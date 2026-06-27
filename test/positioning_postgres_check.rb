# frozen_string_literal: true

# Standalone PostgreSQL verification for Plutonium::Positioning and the
# `t.position` migration helper. The rest of the suite runs on SQLite; this
# check guards the behaviour that differs on an exact-decimal database — the
# `numeric(precision, scale)` column type and the gap-exhaustion rebalance.
#
# Run by the "Positioning on PostgreSQL" CI job (see .github/workflows/main.yml),
# or locally:
#
#   createdb plutonium_test
#   DATABASE_URL=postgres://postgres:postgres@localhost:5432/plutonium_test \
#     BUNDLE_GEMFILE=gemfiles/postgres.gemfile bundle exec ruby test/positioning_postgres_check.rb
#
# Deliberately framework-free (no dummy app, no minitest) so it needs only
# activerecord + pg. Exits non-zero if any check fails.

require "active_record"
require_relative "../lib/plutonium/positioning"

# The railtie isn't running here, so register the migration helper by hand —
# exactly what `initializer "plutonium.positioning"` does in a Rails app.
ActiveRecord::ConnectionAdapters::TableDefinition.include(Plutonium::Positioning::MigrationHelpers)
ActiveRecord::ConnectionAdapters::Table.include(Plutonium::Positioning::MigrationHelpers)

# Collects pass/fail results without leaking globals into the linted codebase.
class Checker
  attr_reader :failures

  def initialize
    @failures = 0
  end

  def check(label)
    ok = yield
    puts "#{ok ? "PASS" : "FAIL"}  #{label}"
    @failures += 1 unless ok
  rescue => e
    puts "FAIL  #{label}  (#{e.class}: #{e.message})"
    @failures += 1
  end
end

ActiveRecord::Base.establish_connection(
  ENV["DATABASE_URL"] || "postgres://postgres:postgres@localhost:5432/plutonium_test"
)
conn = ActiveRecord::Base.connection
abort "This check requires PostgreSQL, got #{conn.adapter_name}" unless conn.adapter_name.match?(/postgres/i)

puts "Connected to: #{conn.adapter_name} #{conn.database_version}"
puts "-" * 60
checker = Checker.new

# ── Migration helper: t.position ────────────────────────────────────────────
conn.create_table(:pu_pos_create, force: true) do |t|
  t.string :status
  t.position
  t.position :sort_order
  t.position :idxd, index: true
end
cols = conn.columns(:pu_pos_create).index_by(&:name)
checker.check("create_table t.position → numeric(16,8)") do
  c = cols.fetch("position")
  c.type == :decimal && c.precision == 16 && c.scale == 8
end
checker.check("sql_type is numeric(16,8)") { cols.fetch("position").sql_type == "numeric(16,8)" }
checker.check("custom name :sort_order created with scale 8") { cols.fetch("sort_order").scale == 8 }
checker.check("index: true added a real index") { conn.index_exists?(:pu_pos_create, :idxd) }

conn.create_table(:pu_pos_override, force: true) { |t| t.position :position, precision: 20, scale: 10 }
checker.check("precision/scale overrides are honored") do
  c = conn.columns(:pu_pos_override).find { |x| x.name == "position" }
  c.precision == 20 && c.scale == 10
end

conn.create_table(:pu_pos_alter, force: true) { |t| t.string :name }
conn.change_table(:pu_pos_alter) { |t| t.position }
checker.check("change_table t.position adds numeric(16,8)") do
  c = conn.columns(:pu_pos_alter).find { |x| x.name == "position" }
  c && c.type == :decimal && c.scale == 8
end

# ── Positioning behaviour on a real model ───────────────────────────────────
conn.create_table(:pu_pos_items, force: true) do |t|
  t.string :status
  t.position
end

klass = Class.new(ActiveRecord::Base) do
  self.table_name = "pu_pos_items"
  include Plutonium::Positioning

  positioned_on :position, scope: :status
end

rebalances = 0
counter = Module.new do
  define_method(:rebalance_scope_group!) do
    rebalances += 1
    super()
  end
end
klass.prepend(counter)

a = klass.create!(status: "todo")
b = klass.create!(status: "todo")
checker.check("create appends: a=1, b=2") { a.position == 1 && b.position == 2 }
checker.check("scope groups are independent") { klass.create!(status: "done").position == 1 }

# reposition between — isolated group so it doesn't pollute the exhaustion loop
ra = klass.create!(status: "rp")
rb = klass.create!(status: "rp")
rc = klass.create!(status: "rp")
rc.reposition!(prev_record: ra, next_record: rb)
checker.check("reposition lands strictly between neighbors") do
  v = rc.reload.position
  v > ra.reload.position && v < rb.reload.position
end

# natural exhaustion → rebalance, drag order preserved (todo group is just a, b)
inserted = []
30.times do
  left, right = klass.where(status: "todo").order(:position).limit(2).to_a
  x = klass.create!(status: "todo")
  x.reposition!(prev_record: left, next_record: right)
  inserted << x
end
checker.check("30 same-slot inserts triggered a rebalance (#{rebalances})") { rebalances >= 1 }

rows = klass.where(status: "todo").order(:position).to_a
checker.check("positions stay distinct across rebalances") do
  positions = rows.map(&:position)
  positions.uniq.length == positions.length
end
checker.check("drag order survives rebalancing") do
  rows.map(&:id) == [a.id] + inserted.reverse.map(&:id) + [b.id]
end

# tie resolution
ta = klass.create!(status: "tie")
tb = klass.create!(status: "tie")
ta.update_column(:position, 1.0)
tb.update_column(:position, 1.0)
tc = klass.create!(status: "tie")
tc.reposition!(prev_record: ta, next_record: tb)
checker.check("identical positions resolved into 3 distinct values") do
  [ta, tb, tc].map { |r| r.reload.position }.uniq.length == 3
end

%i[pu_pos_create pu_pos_override pu_pos_alter pu_pos_items].each do |t|
  conn.drop_table(t, if_exists: true)
end

puts "-" * 60
puts checker.failures.zero? ? "ALL CHECKS PASSED" : "#{checker.failures} CHECK(S) FAILED"
exit(checker.failures.zero? ? 0 : 1)
