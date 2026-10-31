# LOCAL=1 builds from the plutonium-core checkout this template was loaded from
# (-m /path/to/plutonium-core/docs/public/templates/pluton8.rb): its templates
# and its gem, instead of the published ones.
abort "LOCAL=1 needs this template loaded from a plutonium-core checkout (-m /path/to/...)" if ENV["LOCAL"] && !File.file?(__FILE__)

template_location = lambda do |name|
  ENV["LOCAL"] ? File.join(__dir__, name) : "https://radioactive-labs.github.io/plutonium-core/templates/#{name}"
end

after_bundle do
  # Run the plutonium install
  rails_command "app:template LOCATION=#{template_location.call("plutonium.rb")}"

  # Run the lite stack setup (via rails_command so generators are available)
  rails_command "app:template LOCATION=#{template_location.call("lite.rb")}"

  # Wizards + async interactions, last.
  #
  # After lite rather than straight after plutonium, because both of these
  # schedule a recurring job and solid_queue — which lite installs — is what
  # there is to schedule into. Run earlier and each would print "schedule it
  # yourself", leaving the app with a subsystem nothing maintains and no second
  # pass to fix it.
  rails_command "app:template LOCATION=#{template_location.call("experimental.rb")}"
end
