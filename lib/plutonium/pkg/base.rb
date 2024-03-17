module Plutonium
  module Pkg
    module Base
      extend ActiveSupport::Concern

      included do
        # prevent this package from being added to the view lookup
        # since we need finer control over how views are resolved.
        # view lookup configuration is handled at the controller level
        config.before_configuration do
          # this touches the internals of rails, but I could not find a good way of doing this
          # we get the initializer instance and set the block property to a noop
          # There is no error handling, to ensure we know when it breaks.
          add_view_paths_initializer = Rails.application.initializers.find do |a|
            a.context_class == self && a.name.to_s == "add_view_paths"
          end
          add_view_paths_initializer.instance_variable_set(:@block, ->(app) {})
        end
      end
    end
  end
end
