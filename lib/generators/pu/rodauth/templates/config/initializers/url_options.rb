# frozen_string_literal: true

if (default_url = ENV["RAILS_DEFAULT_URL"])
  uri = URI.parse(default_url)
  default_port = (uri.scheme == "https") ? 443 : 80
  url_options = {host: uri.host, protocol: uri.scheme}
    .tap { |opts| opts[:port] = uri.port if uri.port != default_port }

  ActionMailer::Base.default_url_options = url_options if ActionMailer::Base.default_url_options.blank?
  Rails.application.routes.default_url_options = url_options if Rails.application.routes.default_url_options.blank?
end
