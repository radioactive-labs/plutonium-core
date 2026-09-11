# frozen_string_literal: true

module Plutonium
  module Doctor
    module Checks
      # A policy that never says which attributes it permits.
      #
      # `Policy#autodetect_permitted_fields` hands back every field on the model
      # and, outside development, raises rather than doing so — the comment in
      # `Plutonium::Resource::Policy` is blunt about why ("Auto-detected resource
      # fields result in security holes"). In development it only writes a
      # warning to the log, which is exactly where a warning gets missed. So the
      # app works on the machine it was written on and 500s the first time it is
      # deployed.
      #
      # This is not the framework failing to raise; it raises hard. It is the
      # raise landing in the wrong environment to be useful, which is what makes
      # it worth finding early.
      #
      # An entry point the application overrode is not reported, even when the
      # base method underneath it is still Plutonium's: `permitted_attributes_for_edit`
      # answered by the app is answered, and never reaches the autodetecting
      # `permitted_attributes_for_create` below it.
      class AutodetectedPermittedAttributes < Check
        def self.severity = :error

        # The two methods that actually call `autodetect_permitted_fields`.
        BASES = %i[permitted_attributes_for_create permitted_attributes_for_read].freeze

        # How Plutonium's own defaults delegate, from
        # `Plutonium::Resource::Policy`. Hardcoded because the delegation lives
        # in method bodies and cannot be read off the class — and locked to the
        # real thing by AutodetectedPermittedAttributesTest, which probes the
        # base policy and fails if this map ever drifts from it.
        DELEGATIONS = {
          permitted_attributes_for_new: :permitted_attributes_for_create,
          permitted_attributes_for_edit: :permitted_attributes_for_update,
          permitted_attributes_for_update: :permitted_attributes_for_create,
          permitted_attributes_for_index: :permitted_attributes_for_read,
          permitted_attributes_for_show: :permitted_attributes_for_read,
          permitted_attributes_for_export: :permitted_attributes_for_index
        }.freeze

        # What a controller asks for, by action.
        ENTRY_POINTS = %i[
          permitted_attributes_for_index
          permitted_attributes_for_show
          permitted_attributes_for_new
          permitted_attributes_for_edit
          permitted_attributes_for_create
          permitted_attributes_for_update
          permitted_attributes_for_export
        ].freeze

        def call
          reached = Hash.new { |h, k| h[k] = [] }

          ENTRY_POINTS.each do |entry|
            base = autodetecting_base_for(entry)
            reached[base] << entry if base
          end

          reached.map do |base, entries|
            finding(
              subject: "#{target.resource_class}##{base}",
              message: "#{target.policy_class} does not define `#{base}` — it will raise outside development",
              details: <<~TEXT
                Reached by: #{entries.join(", ")}

                Without an override, `#{base}` calls `autodetect_permitted_fields`, which
                permits every field on #{target.resource_class} and raises outside development.
                In development it only logs a warning, so this passes locally and fails on deploy.

                Declare the attributes on #{target.policy_class}:

                    def #{base}
                      %i[#{sample_attributes.join(" ")}]
                    end

                List columns only. A `*_attributes` key for a nested association does not
                belong here — permit those through the nested resource's own policy.
              TEXT
            )
          end
        end

        private

        # Follows Plutonium's delegation from an entry point down to the method
        # that would autodetect, stopping the moment the application has
        # answered for itself.
        #
        # @return [Symbol, nil] the autodetecting base, or nil if nothing autodetects
        def autodetecting_base_for(entry)
          seen = []
          current = entry

          while current
            return nil if app_defined_policy_method?(current)
            return current if BASES.include?(current)

            # Defensive only against a future cycle in DELEGATIONS; the map as
            # written terminates.
            return nil if seen.include?(current)
            seen << current

            current = DELEGATIONS[current]
          end

          nil
        end

        # A few real column names, so the suggested override is copy-pasteable
        # rather than a placeholder.
        def sample_attributes
          names = target.resource_class.resource_field_names
          names -= [target.resource_class.primary_key.to_sym, :created_at, :updated_at]
          names.first(4).presence || %i[name]
        rescue
          %i[name]
        end
      end
    end
  end
end
