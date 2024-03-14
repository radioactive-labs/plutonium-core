module Plutonium
  module Helpers
    extend ActiveSupport::Autoload

    def self.included(base)
      base.class_eval do
        include Plutonium::Helpers::ActionButtonsHelper
        include Plutonium::Helpers::ApplicationHelper
        include Plutonium::Helpers::AttachmentHelper
        include Plutonium::Helpers::ComponentHelper
        include Plutonium::Helpers::ContentHelper
        include Plutonium::Helpers::DisplayHelper
        include Plutonium::Helpers::FormHelper
        include Plutonium::Helpers::TableHelper
        include Plutonium::Helpers::TurboHelper
        include Plutonium::Helpers::TurboStreamActionsHelper
      end
    end

    eager_autoload do
      autoload :ActionButtonsHelper
      autoload :ApplicationHelper
      autoload :AttachmentHelper
      autoload :ContentHelper
      autoload :ComponentHelper
      autoload :DisplayHelper
      autoload :FormHelper
      autoload :TableHelper
      autoload :TurboHelper
      autoload :TurboStreamActionsHelper
    end
  end
end
