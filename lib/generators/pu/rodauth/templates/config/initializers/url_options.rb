# frozen_string_literal: true

Rails.application.config.after_initialize do
  if (default_url = ENV["RAILS_DEFAULT_URL"])
    uri = URI.parse(default_url)
    Rails.application.config.action_mailer.default_url_options ||= {
      host: uri.host,
      port: uri.port,
      protocol: uri.scheme
    }
  end

  Rails.application.routes.default_url_options ||= Rails.application.config.action_mailer.default_url_options
end
