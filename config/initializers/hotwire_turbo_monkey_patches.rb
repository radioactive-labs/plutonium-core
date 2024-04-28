# Work around for https://github.com/hotwired/turbo-rails/issues/512
# When ActionCable is not loaded, Turbo breaks boot
Rails.autoloaders.once.do_not_eager_load("#{Turbo::Engine.root}/app/channels") unless defined?(ActionCable)

# Work around for https://github.com/hotwired/turbo-rails/issues/535
Rails.application.config.after_initialize do
  Turbo::Streams::BroadcastStreamJob.class_eval do
    def self.perform_later(stream, content:)
      super(stream, content: content.to_str)
    end
  end
end
