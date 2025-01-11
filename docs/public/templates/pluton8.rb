after_bundle do
  # Run the plutonium install
  template_location = if ENV["LOCAL"]
    "/Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/plutonium.rb"
  else
    "https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb"
  end
  rails_command "app:template LOCATION=#{template_location}"

  # Enliten!
  rails_command "app:template LOCATION=https://raw.githubusercontent.com/thedumbtechguy/enlitenment/main/template.rb"
end
