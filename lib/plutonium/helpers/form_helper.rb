module Plutonium
  module Helpers
    module FormHelper
      include ActionView::Helpers::FormHelper

      #
      # Override the original form_for helper to disable turbo forms by default if not
      # explicitly opted into
      #
      def resource_form_for(record, options = {}, &block)
        turbo_frame = options.key?(:turbo_frame) ? options[:turbo_frame] : "_top"
        options = {
          html: {
            data: {
              turbo_frame:
            }
          }
        }.deep_merge! options

        simple_form_for(record, options, &block)
      end
    end
  end
end
