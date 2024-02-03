module Plutonium
  module Core
    module Fields
      module Inputs
        class BasicInput
          attr_reader :name, :user_options

          def initialize(name, **user_options)
            @name = name
            @user_options = user_options
          end

          def render(f, record) = f.input name, **options

          def collect(params)
            # Handles multi parameter attributes
            # https://www.cookieshq.co.uk/posts/rails-spelunking-date-select
            # https://www.cookieshq.co.uk/posts/multiparameter-attributes

            # Matches
            # - parameter
            # - parameter(1)
            # - parameter(2)
            # - parameter(1i)
            # - parameter(2f)
            regex = /^#{param}(\(\d+[if]?\))?$/

            params.select { |key| regex.match? key }
          end

          protected

          def input_options = {}

          def param = name

          def options = @options ||= input_options.deep_merge(@user_options)
        end
      end
    end
  end
end
