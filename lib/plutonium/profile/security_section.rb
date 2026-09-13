# frozen_string_literal: true

module Plutonium
  module Profile
    # Renders security settings links based on enabled Rodauth features.
    class SecuritySection < Plutonium::UI::Component::Base
      # Labels and descriptions come from
      # plutonium.profile.security_section.features.<feature>.{label,description}.
      FEATURES = {
        change_password: {
          icon: Phlex::TablerIcons::Key,
          path_method: :change_password_path
        },
        change_login: {
          icon: Phlex::TablerIcons::Mail,
          path_method: :change_login_path
        },
        otp: {
          icon: Phlex::TablerIcons::DeviceMobile,
          path_method: :otp_setup_path
        },
        recovery_codes: {
          icon: Phlex::TablerIcons::FileCode,
          path_method: :recovery_codes_path
        },
        webauthn: {
          icon: Phlex::TablerIcons::Fingerprint,
          path_method: :webauthn_setup_path
        },
        active_sessions: {
          icon: Phlex::TablerIcons::DevicesCheck,
          path_method: :active_sessions_path
        },
        close_account: {
          icon: Phlex::TablerIcons::Trash,
          path_method: :close_account_path,
          danger: true
        }
      }.freeze

      def view_template
        div(class: "mt-8") do
          render_section_header
          render_feature_links
        end
      end

      private

      def render_section_header
        div(class: "mb-4") do
          h2(class: "text-lg font-semibold text-[var(--pu-text)]") { t("plutonium.profile.security_section.title") }
          p(class: "text-sm text-[var(--pu-text-muted)]") { t("plutonium.profile.security_section.description") }
        end
      end

      def render_feature_links
        div(
          class: "bg-[var(--pu-card-bg)] border border-[var(--pu-card-border)] rounded-[var(--pu-radius-lg)] divide-y divide-[var(--pu-border)]",
          style: "box-shadow: var(--pu-shadow-sm)"
        ) do
          enabled_features.each do |feature, config|
            render_feature_link(feature, config)
          end
        end
      end

      def render_feature_link(feature, config)
        path = helpers.rodauth.send(config[:path_method])
        danger = config[:danger]

        a(
          href: path,
          class: tokens(
            "flex items-center gap-4 p-4 hover:bg-[var(--pu-surface-alt)] transition-colors first:rounded-t-[var(--pu-radius-lg)] last:rounded-b-[var(--pu-radius-lg)]",
            danger ? "text-[var(--pu-text-danger)]" : "text-[var(--pu-text)]"
          )
        ) do
          # Icon
          div(class: "flex-shrink-0") do
            render config[:icon].new(class: "w-5 h-5")
          end

          # Content
          div(class: "flex-grow") do
            div(class: "font-medium") { feature_text(feature, :label) }
            div(class: "text-sm text-[var(--pu-text-muted)]") { feature_text(feature, :description) }
          end

          # Arrow
          div(class: "flex-shrink-0 text-[var(--pu-text-muted)]") do
            render Phlex::TablerIcons::ChevronRight.new(class: "w-5 h-5")
          end
        end
      end

      def feature_text(feature, slot)
        t("plutonium.profile.security_section.features.#{feature}.#{slot}")
      end

      def enabled_features
        FEATURES.select { |feature, _config| feature_enabled?(feature) }
      end

      def feature_enabled?(feature)
        helpers.rodauth.features.include?(feature)
      end
    end
  end
end
