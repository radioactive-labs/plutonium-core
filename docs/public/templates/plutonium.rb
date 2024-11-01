# We just installed Rails, let's create a commit
git add: "."
git commit: %( -m 'initial commit' )

# Run the base install
rails_command "app:template LOCATION=/Users/stefan/Documents/plutonium/plutonium-core/docs/public/templates/base.rb"

after_bundle do
end
