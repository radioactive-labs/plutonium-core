module Plutonium
  module Helpers
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
  end
end
