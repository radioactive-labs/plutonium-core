# frozen_string_literal: true

module Plutonium
  module UI
    module Options
      # Shared detector for secret-bearing field names, so every surface masks
      # the same fields: the form (Password input), the show page / table /
      # wizard summary (masked display) and grid / kanban card slots.
      #
      # Covers Phlexi's password names (`password`, `encrypted_*`, `*_password`,
      # `*_digest`, `*_hash`, `*_token`) plus ones it misses (`token`, `salt`,
      # `*_salt`, `*_key`, anything containing `secret`). Still a name
      # heuristic, not a guarantee: opt a field in or out with `as: :password`
      # / `as: :string`.
      module SecretField
        MASK = "••••••••"

        def self.secret_name?(name)
          name = name.to_s.downcase
          %w[password token salt].include?(name) ||
            name.start_with?("encrypted_") ||
            name.end_with?("_password", "_digest", "_hash", "_token", "_salt", "_key") ||
            name.include?("secret")
        end

        private

        def secret_field_name? = SecretField.secret_name?(key)
      end
    end
  end
end
