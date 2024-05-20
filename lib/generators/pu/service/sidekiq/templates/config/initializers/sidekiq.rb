# frozen_string_literal: true

redis_config = {
  url: ENV.fetch("REDIS_QUEUE_URL", ""),
  connect_timeout: 1,  # Defaults to 1 second
  read_timeout: 0.2, # Defaults to 1 second
  write_timeout: 0.2, # Defaults to 1 second
  # https://github.com/redis/redis-rb#reconnections
  reconnect_attempts: [ # Defaults to 1
    0, # retry immediately
    0.25, # retry a second time after 250ms
    1, # retry a third time after another 1s
    5, # retry a fourth time after another 5s
    10 # retry a fifth and final time after another 15s
  ]
}

Sidekiq.configure_client do |config|
  config.redis = redis_config

  # Configure sidekiq client here
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
  config.logger = Rails.logger = Sidekiq::Logger.new($stdout)
  config.death_handlers << lambda { |job, exception|
    worker = job["wrapped"].safe_constantize
    worker&.sidekiq_retries_exhausted_block&.call(job, exception)
  }

  if defined?(Prosopite)
    # configure prosopite
    config.server_middleware do |chain|
      require "prosopite/middleware/sidekiq"
      chain.add(Prosopite::Middleware::Sidekiq)
    end
  end

  # Configure sidekiq server here
end

# Use sidekiq
Rails.application.config.active_job.queue_adapter = :sidekiq

# nil will use the "default" queue
# some of these options will not work with your Rails version. add/remove as necessary
Rails.application.config.action_mailer.deliver_later_queue_name = nil if Rails.application.config.respond_to?(:action_mailbox)  # defaults to "mailers"
Rails.application.config.action_mailbox.queues.routing = nil if Rails.application.config.respond_to?(:action_mailbox)  # defaults to "action_mailbox_routing"
Rails.application.config.active_storage.queues.analysis = nil if Rails.application.config.respond_to?(:active_storage)  # defaults to "active_storage_analysis"
Rails.application.config.active_storage.queues.purge = nil if Rails.application.config.respond_to?(:active_storage)  # defaults to "active_storage_purge"
Rails.application.config.active_storage.queues.mirror = nil if Rails.application.config.respond_to?(:active_storage)  # defaults to "active_storage_mirror"
Rails.application.config.active_storage.queues.purge = :low if Rails.application.config.respond_to?(:active_storage) # put purge jobs in the `low` queue
