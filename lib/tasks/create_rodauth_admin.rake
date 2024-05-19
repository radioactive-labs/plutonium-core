namespace :rodauth do
  desc "Create a Rodauth admin account"
  task admin: :environment do
    # require "rodauth"
    # require "active_record"
    require "tty-prompt"

    prompt = TTY::Prompt.new
    email = ENV["EMAIL"] || prompt.ask("email:", required: true)
    # password = SecureRandom.hex
    # password = ENV["PASSWORD"] || prompt.mask("password:", required: true)
    # password_confirm = ENV["PASSWORD"] || prompt.mask("password:", required: true)

    RodauthApp.rodauth(:admin).create_account(login: email)
  end
end
