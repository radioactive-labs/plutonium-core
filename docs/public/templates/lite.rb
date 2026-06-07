after_bundle do
  # SQLite infrastructure (replaces Redis/Postgres for simple deployments)
  generate "pu:lite:setup"
  git add: "."
  git commit: %( -m 'chore: setup sqlite') if `git status --porcelain`.present?

  generate "pu:lite:tune"
  git add: "."
  git commit: %( -m 'chore: tune sqlite pragmas') if `git status --porcelain`.present?

  unless ENV["SKIP_SOLID_QUEUE"]
    generate "pu:lite:solid_queue"
    git add: "."
    git commit: %( -m 'chore: add solid_queue') if `git status --porcelain`.present?
  end

  unless ENV["SKIP_SOLID_CACHE"]
    generate "pu:lite:solid_cache"
    git add: "."
    git commit: %( -m 'chore: add solid_cache') if `git status --porcelain`.present?
  end

  unless ENV["SKIP_SOLID_CABLE"]
    generate "pu:lite:solid_cable"
    git add: "."
    git commit: %( -m 'chore: add solid_cable') if `git status --porcelain`.present?
  end

  unless ENV["SKIP_SOLID_ERRORS"]
    generate "pu:lite:solid_errors"
    git add: "."
    git commit: %( -m 'chore: add solid_errors') if `git status --porcelain`.present?
  end

  unless ENV["SKIP_LITESTREAM"]
    generate "pu:lite:litestream"
    git add: "."
    git commit: %( -m 'chore: add litestream') if `git status --porcelain`.present?
  end

  unless ENV["SKIP_RAILS_PULSE"]
    generate "pu:lite:rails_pulse"
    git add: "."
    git commit: %( -m 'chore: add rails_pulse') if `git status --porcelain`.present?
  end

  unless ENV["SKIP_SQLITE_MAINTENANCE"]
    generate "pu:lite:maintenance"
    git add: "."
    git commit: %( -m 'chore: add sqlite maintenance job') if `git status --porcelain`.present?
  end
end
