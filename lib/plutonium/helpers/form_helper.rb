module Plutonium
  module Helpers
    module FormHelper
      include ActionView::Helpers::FormHelper

      alias_method :pu_overridden_form_for, :form_for

      #
      # Override the original form_for helper to disable turbo forms by default if not
      # explicitly opted into
      #
      def form_for(record, options = {}, &block)
        turbo_frame = options.key?(:turbo_frame) ? options[:turbo_frame] : "_top"
        options = {
          html: {
            data: {
              turbo_frame:
            }
          }
        }.deep_merge! options

        pu_overridden_form_for(record, options, &block)
      end
    end
  end
end
