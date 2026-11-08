module Hr
  class ResourcePolicy < ::ResourcePolicy
    include Plutonium::Rbac::Policy
  end
end
