after_bundle do
  # We just installed Rails, let's create a commit
  git(add: ".") && git(commit: %( -m 'chore: initial commit' ))

  # Run the base install
  template_location = if ENV["LOCAL"]
    "/Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/base.rb"
  else
    "https://radioactive-labs.github.io/plutonium-core/templates/base.rb"
  end
  rails_command "app:template LOCATION=#{template_location}"

  # Add development tools
  generate "pu:gem:dotenv"
  git(add: ".") && git(commit: %( -m 'chore: add dotenv' ))

  generate "pu:gem:annotated"
  git(add: ".") && git(commit: %( -m 'chore: add annotate' ))

  generate "pu:gem:standard"
  git(add: ".") && git(commit: %( -m 'chore: add standardrb' ))

  generate "pu:gem:letter_opener"
  git(add: ".") && git(commit: %( -m 'chore: add letter_opener' ))

  generate "pu:gem:actual_db_schema"
  git(add: ".") && git(commit: %( -m 'chore: add actual_db_schema' ))

  generate "pu:core:assets"
  git(add: ".") && git(commit: %( -m 'chore: integrate assets' ))

  generate "pu:skills:sync"
  git(add: ".") && git(commit: %( -m 'chore: sync plutonium skills' ))
end
