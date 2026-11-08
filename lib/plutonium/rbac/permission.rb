# frozen_string_literal: true

module Plutonium
  module Rbac
    # One grantable permission. `resource` is the model class (nil for a
    # hand-declared permission), `action` the action or "<field>.<read|write>".
    Permission = Data.define(:key, :resource, :action, :label, :group)
  end
end
