# frozen_string_literal: true

module Plutonium
  module Testing
    # Run a block as if the current holder had exactly these permission keys.
    #
    #   with_rbac_permissions("blogging/post.read") { assert policy.read? }
    module Rbac
      def with_rbac_permissions(*keys)
        previous = Plutonium::Rbac::Current.permission_override
        Plutonium::Rbac::Current.permission_override = keys.flatten.map(&:to_s).to_set
        yield
      ensure
        Plutonium::Rbac::Current.permission_override = previous
      end
    end
  end
end
