return if ENV["SECRET_KEY_BASE_DUMMY"].present?

# In development/test, only check if dotenv is loaded (process may not have reloaded yet)
return if Rails.env.local? && !defined?(Dotenv)

# Add required env vars to this list
required_env_vars = %w[
  RAILS_DEFAULT_URL
]

if Rails.env.production?
  required_env_vars += %w[RAILS_MASTER_KEY DATABASE_URL]
end

# Add additional env vars here

# Check required env vars
required_env_vars.each do |env_var|
  if !ENV.has_key?(env_var) || ENV[env_var].blank?
    raise <<~EOL
      Missing required environment variable: #{env_var}

      Ask a teammate for the appropriate value.
    EOL
  end
end
