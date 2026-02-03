# frozen_string_literal: true

return unless defined?(Rodauth::Rails)

require "rails/generators/named_base"
require_relative "../lib/plutonium_generators"

module Pu
  module Saas
    class UserGenerator < ::Rails::Generators::NamedBase
      include PlutoniumGenerators::Concerns::Logger

      source_root File.expand_path("templates", __dir__)

      desc "Generate a SaaS user account with Rodauth integration"

      class_option :allow_signup, type: :boolean, default: true,
        desc: "Whether to allow users to sign up to the platform"

      class_option :extra_attributes, type: :array, default: [],
        desc: "Additional attributes to add to the account model (e.g., name:string)"

      def start
        generate_user_account
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def generate_user_account
        invoke "pu:rodauth:account", [name],
          defaults: false,
          **user_features,
          extra_attributes: Array(options[:extra_attributes]),
          force: options[:force],
          skip: options[:skip],
          lint: true
      end

      def user_features
        features = %i[
          login
          remember
          logout
          create_account
          verify_account
          verify_account_grace_period
          reset_password
          reset_password_notify
          change_login
          verify_login_change
          change_password
          change_password_notify
          case_insensitive_login
          internal_request
        ]

        features.delete(:create_account) unless options[:allow_signup]
        features.map { |feature| [feature, true] }.to_h
      end

      def normalized_name = name.underscore
    end
  end
end
