class ResourcePolicy < Plutonium::Resource::Policy
  def create?
    true
  end

  def read?
    true
  end
end
