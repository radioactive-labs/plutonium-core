after_bundle do
  # Run the plutonium install
  template_location = if ENV["LOCAL"]
    "/Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/plutonium.rb"
  else
    "https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb"
  end
  rails_command "app:template LOCATION=#{template_location}"

  # SQLite infrastructure (replaces Redis/Postgres for simple deployments)
  generate "pu:lite:setup"
  git add: ".", commit: %( -m 'setup sqlite')

  unless ENV["SKIP_SOLID_QUEUE"]
    generate "pu:lite:solid_queue"
    git add: ".", commit: %( -m 'add solid_queue')
  end

  unless ENV["SKIP_SOLID_CACHE"]
    generate "pu:lite:solid_cache"
    git add: ".", commit: %( -m 'add solid_cache')
  end

  unless ENV["SKIP_SOLID_CABLE"]
    generate "pu:lite:solid_cable"
    git add: ".", commit: %( -m 'add solid_cable')
  end

  unless ENV["SKIP_SOLID_ERRORS"]
    generate "pu:lite:solid_errors"
    git add: ".", commit: %( -m 'add solid_errors')
  end

  unless ENV["SKIP_LITESTREAM"]
    generate "pu:lite:litestream"
    git add: ".", commit: %( -m 'add litestream')
  end

  unless ENV["SKIP_RAILS_PULSE"]
    generate "pu:lite:rails_pulse"
    git add: ".", commit: %( -m 'add rails_pulse')
  end
end
