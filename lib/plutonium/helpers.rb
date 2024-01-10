module Plutonium
  module Helpers
    extend ActiveSupport::Autoload

    def self.included(base)
      base.class_eval do
        include Plutonium::Helpers::ApplicationHelper
        include Plutonium::Helpers::ActionButtonsHelper
        include Plutonium::Helpers::ContentHelper
        include Plutonium::Helpers::FormHelper
        include Plutonium::Helpers::MenuHelper
        include Plutonium::Helpers::PaginationHelper
        include Plutonium::Helpers::DisplayHelper
        include Plutonium::Helpers::TurboHelper
        include Plutonium::Helpers::AttachmentHelper
      end
    end

    eager_autoload do
      autoload :ApplicationHelper
      autoload :ActionButtonsHelper
      autoload :ContentHelper
      autoload :FormHelper
      autoload :MenuHelper
      autoload :PaginationHelper
      autoload :DisplayHelper
      autoload :TurboHelper
      autoload :AttachmentHelper
    end
  end
end
