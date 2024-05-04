module Plutonium
  module Core
    module Fields
      module Inputs
        class PhoneInput < SimpleFormInput
          # def render(view_context, f, record, **opts)
          #   opts = options.deep_merge opts
          #   opts.delete(:as)
          #   f.input name, **opts
          # end

          # def collect(params)
          #   value = params[param]
          #   country = user_options[:country]
          #   country ||= params[user_options[:country_param].to_sym] if user_options[:country_param].present?
          #   {param => Phonelib.parse(value, country).full_e164}
          # end
        end
      end
    end
  end
end
