after_bundle do
  # We just installed Rails, let's create a commit
  git add: "."
  git commit: %( -m 'initial commit' )

  # Run the base install
  rails_command "app:template LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/base.rb"

  # Add development tools
  generate "pu:gem:dotenv"
  git add: "."
  git commit: %( -m 'add dotenv' )

  generate "pu:gem:annotate"
  git add: "."
  git commit: %( -m 'add annotate' )

  generate "pu:core:assets"
  git add: "."
  git commit: %( -m 'integrate assets' )
end
