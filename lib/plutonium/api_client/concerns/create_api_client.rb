# frozen_string_literal: true

module Plutonium
  module ApiClient
    module Concerns
      # CreateApiClient provides the core logic for creating API client accounts.
      #
      # Include this in your CreateInteraction and implement the required methods.
      #
      # @example Basic usage
      #   class ApiClient::CreateInteraction < Plutonium::Resource::Interaction
      #     include Plutonium::ApiClient::Concerns::CreateApiClient
      #
      #     input :role, as: :select, choices: OrganizationApiClient.roles.keys
      #
      #     def membership_class
      #       OrganizationApiClient
      #     end
      #
      #     def role
      #       attributes[:role] || "read_only"
      #     end
      #   end
      #
      module CreateApiClient
        extend ActiveSupport::Concern
        include Plutonium::Interaction::Concerns::Scoping

        included do
          presents label: "Create API Client", icon: Phlex::TablerIcons::Key

          attribute :login, :string

          validates :login, presence: true
        end

        def execute
          password = generate_secure_password

          rodauth_instance.create_account(
            login: login,
            password: password
          )

          # Rodauth internal_request returns nil, so we need to find the account
          api_client = api_client_class.find_by!(login: login)

          create_membership!(api_client) if entity_scoped_api_client?

          succeed(api_client).with_render_response(
            credentials_page_class.new(
              login: api_client.login,
              password: password,
              parent: scoped_parent
            )
          )
        rescue ActiveRecord::RecordNotFound => e
          failed(login: "Failed to create account: #{e.message}")
        rescue => e
          failed(login: e.message)
        end

        private

        # Override to specify the Rodauth configuration name
        # @return [Symbol]
        def rodauth_name
          raise NotImplementedError, "#{self.class}#rodauth_name must return the Rodauth configuration name (e.g., :api_client)"
        end

        # Override to specify the API client model class
        # @return [Class]
        def api_client_class
          raise NotImplementedError, "#{self.class}#api_client_class must return the API client model class"
        end

        # Override to specify the entity model class for scoping
        # @return [Class, nil]
        def entity_class
          nil
        end

        # Override to specify the membership model class
        # @return [Class, nil]
        def membership_class
          nil
        end

        # Override to specify the role to assign
        # @return [String, Symbol, nil]
        def role
          nil
        end

        # Override to add additional attributes when creating the membership
        # @return [Hash]
        def additional_membership_attributes
          {}
        end

        # Override to customize the credentials page class
        # @return [Class]
        def credentials_page_class
          CredentialsPage
        end

        # Override to customize password generation
        # @return [String]
        def generate_secure_password
          SecureRandom.base64(32)
        end

        def rodauth_instance
          RodauthApp.rodauth(rodauth_name)
        end

        def entity_scoped_api_client?
          entity_class.present? && membership_class.present? && scoped_entity_id.present?
        end

        def scoped_entity
          return unless entity_class

          scoped_record_of_type(entity_class)
        end

        def scoped_entity_id
          scoped_entity&.id
        end

        def create_membership!(api_client)
          attrs = {
            entity_foreign_key => scoped_entity_id,
            api_client_foreign_key => api_client.id,
            **additional_membership_attributes
          }
          attrs[:role] = role if role.present?

          membership_class.create!(attrs)
        end

        def entity_foreign_key
          :"#{entity_class.model_name.singular}_id"
        end

        def api_client_foreign_key
          :"#{api_client_class.model_name.singular}_id"
        end

        # Default credentials page - can be overridden
        class CredentialsPage < Plutonium::UI::Page::Base
          def initialize(login:, password:, parent: nil)
            @login = login
            @password = password
            @parent = parent
          end

          def view_template
            div(class: "max-w-2xl mx-auto py-8") do
              render_success_banner
              render_credentials_card
              render_action_buttons
            end
          end

          private

          def render_success_banner
            div(class: "bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-6 mb-6") do
              div(class: "flex items-center gap-3 mb-4") do
                render_check_icon
                h2(class: "text-xl font-semibold text-green-800 dark:text-green-200") { success_title }
              end

              p(class: "text-green-700 dark:text-green-300") do
                strong { "Important: " }
                plain "Save these credentials now. The password cannot be retrieved later."
              end
            end
          end

          def render_credentials_card
            div(class: "bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-6 space-y-4") do
              render_credential_field("Login", @login)
              render_credential_field("Password", @password)
            end
          end

          def render_credential_field(label, value)
            div(class: "space-y-1", data: {controller: "clipboard"}) do
              label(class: "block text-sm font-medium text-gray-700 dark:text-gray-300") { label }
              div(class: "flex items-center gap-2") do
                input(
                  type: "text",
                  value: value,
                  readonly: true,
                  data: {clipboard_target: "source"},
                  class: "flex-1 px-3 py-2 bg-gray-50 dark:bg-gray-900 border border-gray-300 dark:border-gray-600 rounded-md font-mono text-sm select-all focus:ring-2 focus:ring-primary-500"
                )
                button(
                  type: "button",
                  data: {action: "clipboard#copy"},
                  class: "px-3 py-2 text-sm bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 rounded-md transition-colors"
                ) { "Copy" }
              end
            end
          end

          def render_action_buttons
            credentials_text = "Login: #{@login}\nPassword: #{@password}"

            div(class: "mt-6 flex gap-4", data: {controller: "clipboard"}) do
              input(type: "hidden", value: credentials_text, data: {clipboard_target: "source"})
              button(
                type: "button",
                data: {action: "clipboard#copy"},
                class: "px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-md transition-colors"
              ) { "Copy All" }

              a(
                href: done_url,
                class: "px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-md transition-colors"
              ) { "Done" }
            end
          end

          def render_check_icon
            svg(
              class: "w-8 h-8 text-green-600 dark:text-green-400",
              fill: "none",
              stroke: "currentColor",
              viewBox: "0 0 24 24"
            ) do |s|
              s.path(
                stroke_linecap: "round",
                stroke_linejoin: "round",
                stroke_width: "2",
                d: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              )
            end
          end

          # Override in subclass to customize
          def success_title
            "API Client Created Successfully"
          end

          # Override in subclass to customize the done URL
          def done_url
            helpers.url_for(action: :index)
          end
        end
      end
    end
  end
end
