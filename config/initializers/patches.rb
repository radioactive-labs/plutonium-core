# this is required to circumvent an issue with turbo loading action cable even if it is not included in rails
Rails.autoloaders.once.do_not_eager_load("#{Turbo::Engine.root}/app/channels")
