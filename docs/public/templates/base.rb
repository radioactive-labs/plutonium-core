after_bundle do
  Bundler.with_unbundled_env do
    if ENV["LOCAL"]
      run %(bundle add plutonium --path="#{File.expand_path("../../..", __dir__)}")
    else
      run "bundle add plutonium"
    end
  end

  generate "pu:core:install"

  git add: "."
  git commit: %( -m 'chore: install plutonium' )
end
