after_bundle do
  # Run the plutonium install
  template_location = if ENV["LOCAL"]
    "/Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/plutonium.rb"
  else
    "https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb"
  end
  rails_command "app:template LOCATION=#{template_location}"

  # Run the lite stack setup (via rails_command so generators are available)
  lite_location = if ENV["LOCAL"]
    "/Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/lite.rb"
  else
    "https://radioactive-labs.github.io/plutonium-core/templates/lite.rb"
  end
  rails_command "app:template LOCATION=#{lite_location}"

  # Wizards + async interactions, last.
  #
  # After lite rather than straight after plutonium, because both of these
  # schedule a recurring job and solid_queue — which lite installs — is what
  # there is to schedule into. Run earlier and each would print "schedule it
  # yourself", leaving the app with a subsystem nothing maintains and no second
  # pass to fix it.
  experimental_location = if ENV["LOCAL"]
    "/Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/experimental.rb"
  else
    "https://radioactive-labs.github.io/plutonium-core/templates/experimental.rb"
  end
  rails_command "app:template LOCATION=#{experimental_location}"
end
