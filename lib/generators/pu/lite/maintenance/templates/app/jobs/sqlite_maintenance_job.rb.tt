class SqliteMaintenanceJob < ApplicationJob
  queue_as :default

  # Isolated connection for maintenance. Establishing on this dedicated
  # abstract class (instead of ActiveRecord::Base) means we never mutate
  # the global primary connection — a sibling job on the other worker
  # thread keeps talking to the right database.
  class MaintenanceConnection < ActiveRecord::Base
    self.abstract_class = true
  end

  # Names match the keys in config/database.yml. Add your own database
  # names here if you run extra SQLite databases.
  #
  # PRAGMA optimize is cheap (just refreshes query-planner stats, brief
  # shared lock) so it runs everywhere. Full VACUUM rewrites the file
  # under a global *exclusive* lock for its whole duration, so it only
  # runs on databases without live 24/7 writers.
  OPTIMIZE_DBS = %w[primary queue cache cable errors rails_pulse].freeze

  # queue/cable/cache are deliberately excluded: SolidQueue, Solid Cable
  # and Solid Cache write to them constantly, and a VACUUM lock there
  # stalls (and errors out) those processes — e.g. SolidQueue's process
  # deregistration hitting "database is locked". They also barely benefit:
  # in WAL mode deleted pages land on the freelist and get reused, so a
  # churning DB sits at a steady-state size without nightly reclamation.
  VACUUM_DBS = %w[primary errors rails_pulse].freeze

  def perform
    OPTIMIZE_DBS.each { |db_name| run_maintenance(db_name) }
  end

  private

  def run_maintenance(db_name)
    config = ActiveRecord::Base.configurations.configs_for(
      env_name: Rails.env,
      name: db_name,
      include_hidden: true
    )
    return unless config

    MaintenanceConnection.establish_connection(config)
    MaintenanceConnection.connection_pool.with_connection do |conn|
      Rails.logger.info { "[SqliteMaintenance] PRAGMA optimize on #{db_name}" }
      conn.execute("PRAGMA optimize")

      next unless VACUUM_DBS.include?(db_name)

      Rails.logger.info { "[SqliteMaintenance] VACUUM on #{db_name}" }
      started = Time.current
      conn.execute("VACUUM")
      Rails.logger.info { "[SqliteMaintenance] VACUUM on #{db_name} done in #{(Time.current - started).round(2)}s" }
    end
  rescue => e
    Rails.error.report(e, context: {db: db_name, action: "sqlite_maintenance"})
  ensure
    MaintenanceConnection.remove_connection
  end
end
