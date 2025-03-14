module Plutonium
  module Helpers
    def self.included(base)
      base.class_eval do
        include Plutonium::Helpers::ApplicationHelper
        include Plutonium::Helpers::AttachmentHelper
        include Plutonium::Helpers::ContentHelper
        include Plutonium::Helpers::DisplayHelper
        include Plutonium::Helpers::TableHelper
        include Plutonium::Helpers::TurboHelper
        include Plutonium::Helpers::TurboStreamActionsHelper
        include Plutonium::Helpers::AssetsHelper
      end
    end
  end
end
