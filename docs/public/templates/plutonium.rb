after_bundle do
  # We just installed Rails, let's create a commit
  git(add: ".") && git(commit: %( -m 'initial commit' ))

  # Run the base install
  template_location = if ENV["LOCAL"]
    "/Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/base.rb"
  else
    "https://radioactive-labs.github.io/plutonium-core/templates/base.rb"
  end
  rails_command "app:template LOCATION=#{template_location}"

  # Add development tools
  generate "pu:gem:dotenv"
  git(add: ".") && git(commit: %( -m 'add dotenv' ))

  generate "pu:gem:annotated"
  git(add: ".") && git(commit: %( -m 'add annotate' ))

  generate "pu:gem:standard"
  git(add: ".") && git(commit: %( -m 'add standardrb' ))

  generate "pu:gem:letter_opener"
  git(add: ".") && git(commit: %( -m 'add letter_opener' ))

  generate "pu:gem:ahoy"
  git(add: ".") && git(commit: %( -m 'add ahoy for tracking visits and events' ))

  generate "pu:core:assets"
  git(add: ".") && git(commit: %( -m 'integrate assets' ))
end
