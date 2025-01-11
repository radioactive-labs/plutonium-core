after_bundle do
  Bundler.with_unbundled_env do
    run "bundle add plutonium"
  end

  generate "pu:core:install"

  git add: "."
  git commit: %( -m 'install plutonium' )
end
