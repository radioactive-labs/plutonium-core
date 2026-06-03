# frozen_string_literal: true

require "digest"

module Plutonium
  module UI
    module Display
      module Components
        # Renders a scalar value (typically an enum / status) as a colored pill.
        #
        #   display :status, as: :badge
        #   display :status, as: :badge, colors: {archived: :neutral, vip: :accent}
        class Badge < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          VARIANTS = %i[neutral primary secondary success danger warning info accent].freeze

          # Decorative variants used for values with no semantic meaning, chosen
          # deterministically so a given value always gets the same color.
          DECORATIVE = %i[primary secondary info accent].freeze

          SEMANTIC_VARIANTS = {
            "active" => :success, "approved" => :success, "completed" => :success,
            "complete" => :success, "success" => :success, "succeeded" => :success,
            "paid" => :success, "published" => :success, "enabled" => :success,
            "confirmed" => :success, "verified" => :success, "live" => :success,
            "available" => :success, "fulfilled" => :success, "done" => :success,
            "pending" => :warning, "processing" => :warning, "in_progress" => :warning,
            "draft" => :warning, "review" => :warning, "waiting" => :warning,
            "scheduled" => :warning, "trial" => :warning, "paused" => :warning,
            "on_hold" => :warning, "partial" => :warning,
            "failed" => :danger, "rejected" => :danger, "cancelled" => :danger,
            "canceled" => :danger, "error" => :danger, "inactive" => :danger,
            "disabled" => :danger, "expired" => :danger, "banned" => :danger,
            "blocked" => :danger, "closed" => :danger, "unpaid" => :danger,
            "overdue" => :danger, "refunded" => :danger, "declined" => :danger,
            "new" => :info, "queued" => :info, "open" => :info, "info" => :info
          }.freeze

          def self.variant_for(value, colors: nil)
            return :neutral if value.nil?

            if colors
              override = colors[value] || colors[value.to_s.to_sym] || colors[value.to_s]
              return override if override && VARIANTS.include?(override.to_sym)
            end

            key = value.to_s.downcase
            SEMANTIC_VARIANTS[key] || decorative_variant_for(key)
          end

          # Stable across processes (String#hash is seeded, so we digest instead).
          def self.decorative_variant_for(key)
            index = Digest::SHA256.hexdigest(key)[0, 8].to_i(16) % DECORATIVE.size
            DECORATIVE[index]
          end

          def self.humanize(value)
            value.to_s.humanize
          end

          def render_value(value)
            variant = self.class.variant_for(value, colors: @colors)
            span(**attributes, class: tokens("pu-badge", "pu-badge-#{variant}")) do
              plain self.class.humanize(value)
            end
          end

          protected

          def build_attributes
            @colors = attributes.delete(:colors)
            super
          end

          def normalize_value(value)
            value
          end
        end
      end
    end
  end
end
