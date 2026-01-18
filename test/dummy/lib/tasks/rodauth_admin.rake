namespace :rodauth do
  desc "Create a admin account"
  task admin: :environment do
    require "tty-prompt"

    prompt = TTY::Prompt.new
    email = ENV["EMAIL"] || prompt.ask("Email:", required: true)

    RodauthApp.rodauth(:admin).create_account(login: email)
  end
end
