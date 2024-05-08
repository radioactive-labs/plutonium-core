gem "plutonium"

after_bundle do
  generate "pu:core:install"

  git add: "."
  git commit: %( -m 'Install plutonium' )
end
