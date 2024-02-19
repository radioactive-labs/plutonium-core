module Plutonium
  module Helpers
    module FormHelper
      include ActionView::Helpers::FormHelper

      def resource_form_for(record, options = {}, &block)
        turbo_frame = options.key?(:turbo_frame) ? options[:turbo_frame] : "_top"
        options = {
          html: {
            data: {
              turbo_frame:
            }
          }
        }.deep_merge! options

        # record = adapt_route_args(record) unless record.is_a?(Array) || options.key?(:url)

        simple_form_for(record, options, &block)
      end
    end
  end
end
