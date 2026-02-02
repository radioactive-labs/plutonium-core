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
end
