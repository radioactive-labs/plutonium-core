require "rabl"

# https://github.com/nesquena/rabl#configuration

# RABL encodes its result hash with stdlib JSON by default, which serializes
# Time/Date/BigDecimal via #to_s — e.g. a datetime becomes
# "2026-06-04 13:46:18 UTC" instead of the ISO 8601 "2026-06-04T13:46:18.000Z"
# that JSON clients expect. Routing values through ActiveSupport's #as_json
# first yields JSON-optimized values (ISO 8601 datetimes, "YYYY-MM-DD" dates,
# numeric-safe decimals, true/false booleans), then stdlib JSON.generate
# encodes the now-primitive hash without escaping HTML entities in strings.
module Plutonium
  module RablJsonEngine
    def self.dump(object)
      JSON.generate(object.as_json)
    end
  end
end

Rabl.configure do |config|
  config.cache_sources = !Rails.env.development? # Defaults to false
  config.raise_on_missing_attribute = !Rails.env.production? # Defaults to false
  config.json_engine = Plutonium::RablJsonEngine
end

# Extend Rabl source lookup to make it compatible with Rails view lookup
module Rabl
  module Sources
    module RailsViewLookupExtension
      private

      # Returns the rabl template path for Rails
      def fetch_rails_source(file, options = {})
        # use Rails template resolution mechanism if possible (find_template)
        source_format = request_format if defined?(request_format)

        lookup_proc = lambda do |partial|
          context_scope.lookup_context.find(file, context_scope.lookup_context.prefixes, partial, [],
            {formats: [source_format]})
        end

        template = begin
          lookup_proc.call(false)
        rescue
          nil
        end

        template ||= begin
          lookup_proc.call(true)
        rescue
          nil
        end

        template&.identifier
      end
    end

    prepend RailsViewLookupExtension
  end
end

Rabl.register!
