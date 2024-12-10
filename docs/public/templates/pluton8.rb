after_bundle do
  # Run the plutonium install
  rails_command "app:template LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb"

  # Enliten!
  rails_command "app:template LOCATION=https://raw.githubusercontent.com/thedumbtechguy/enlitenment/main/template.rb"
end
