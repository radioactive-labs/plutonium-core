# frozen_string_literal: true

# RBAC resolves the holder through ::ResourcePolicy#rbac_holder (or a portal's
# <Portal>::ResourcePolicy module). These swap those constants for one test and
# put the originals back afterwards, so no dummy file changes and nothing leaks.
module RbacHelpers
  # Replaces ::ResourcePolicy with a subclass of the real one; the block is
  # evaluated in its body.
  def swap_resource_policy(&body)
    stand_in = Class.new(::ResourcePolicy)
    swap_constant(Object, :ResourcePolicy, stand_in)
    stand_in.class_eval(&body) if body
    stand_in
  end

  # ::ResourcePolicy#rbac_holder runs the block in the policy.
  def stub_rbac_holder(&resolver)
    swap_resource_policy { define_method(:rbac_holder) { instance_exec(&resolver) } }
  end

  # Replaces <portal>::ResourcePolicy with a module built from the block.
  def swap_portal_policy(portal, &body)
    swap_constant(portal, :ResourcePolicy, Module.new(&body))
  end

  def swap_constant(owner, name, value)
    (@swapped_constants ||= []) << [owner, name, owner.const_get(name, false)]
    owner.send(:remove_const, name)
    owner.const_set(name, value)
  end

  def after_teardown
    @swapped_constants&.reverse_each do |owner, name, original|
      owner.send(:remove_const, name)
      owner.const_set(name, original)
    end
    @swapped_constants = nil
    super
  end
end
