after_bundle do
  Bundler.with_unbundled_env do
    if ENV["LOCAL"]
      run %(bundle add plutonium --path="/Users/stefan/Documents/plutonium/plutonium-core")
    else
      run "bundle add plutonium"
    end
  end

  generate "pu:core:install"

  git add: "."
  git commit: %( -m 'install plutonium' )
end
