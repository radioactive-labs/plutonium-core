# frozen_string_literal: true

module Plutonium
  module Profile
    # Renders security settings links based on enabled Rodauth features.
    class SecuritySection < Plutonium::UI::Component::Base
      FEATURES = {
        change_password: {
          label: "Change Password",
          description: "Update your account password",
          icon: Phlex::TablerIcons::Key,
          path_method: :change_password_path
        },
        change_login: {
          label: "Change Email",
          description: "Update your email address",
          icon: Phlex::TablerIcons::Mail,
          path_method: :change_login_path
        },
        otp: {
          label: "Two-Factor Authentication",
          description: "Add an extra layer of security",
          icon: Phlex::TablerIcons::DeviceMobile,
          path_method: :otp_setup_path
        },
        recovery_codes: {
          label: "Recovery Codes",
          description: "View or regenerate backup codes",
          icon: Phlex::TablerIcons::FileCode,
          path_method: :recovery_codes_path
        },
        webauthn: {
          label: "Security Keys",
          description: "Manage passkeys and security keys",
          icon: Phlex::TablerIcons::Fingerprint,
          path_method: :webauthn_setup_path
        },
        active_sessions: {
          label: "Active Sessions",
          description: "View and manage your sessions",
          icon: Phlex::TablerIcons::DevicesCheck,
          path_method: :active_sessions_path
        },
        close_account: {
          label: "Close Account",
          description: "Permanently delete your account",
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
          h2(class: "text-lg font-semibold text-[var(--pu-text)]") { "Security Settings" }
          p(class: "text-sm text-[var(--pu-text-muted)]") { "Manage your account security" }
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
            div(class: "font-medium") { config[:label] }
            div(class: "text-sm text-[var(--pu-text-muted)]") { config[:description] }
          end

          # Arrow
          div(class: "flex-shrink-0 text-[var(--pu-text-muted)]") do
            render Phlex::TablerIcons::ChevronRight.new(class: "w-5 h-5")
          end
        end
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
