# Plutonium's experimental subsystems: wizards and async interactions.
#
# Both are off by default — their flags gate their MIGRATIONS as well as their
# behaviour, so an app that has not opted in has neither table. This turns them
# on and schedules the recurring jobs each one needs to stay healthy.
#
# Kept out of plutonium.rb because it is the baseline install, and these two are
# marked experimental: their DSL and behaviour may change in a future release.
# Opting a new app in is a choice, not a default.
after_bundle do
  # SweepJob is the only thing that cleans up the partial domain records an
  # abandoned `on_submit` wizard leaves behind. Unscheduled, those accumulate.
  unless ENV["SKIP_WIZARDS"]
    generate "pu:wizards:install"
    git add: "."
    git commit: %( -m 'chore: enable wizards') if `git status --porcelain`.present?
  end

  # --skip-portal: a fresh app has no portals yet, only main_app — the wrong home
  # for the run resource in an app about to grow them. This turns the subsystem
  # on; `rails g pu:async_interactions:install --dest=<portal>` connects the
  # progress page and running banner once there is a portal worth naming.
  unless ENV["SKIP_ASYNC_INTERACTIONS"]
    generate "pu:async_interactions:install --skip-portal"
    git add: "."
    git commit: %( -m 'chore: enable async interactions') if `git status --porcelain`.present?
  end

  # Both gate their migration paths on the flags just written, and this process
  # booted before either existed.
  rails_command "db:migrate"
  git add: "."
  git commit: %( -m 'chore: migrate wizard + async run tables') if `git status --porcelain`.present?
end
