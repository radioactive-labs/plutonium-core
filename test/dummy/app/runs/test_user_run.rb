# frozen_string_literal: true

# A targeted run over User, used to exercise namespace-driven policy resolution.
#
# User is the vehicle because OrgPortal::UserPolicy narrows the relation scope
# through the `relation_scope do |relation|` MACRO, which is the form ActionPolicy
# actually dispatches to. A policy that defines `def relation_scope(relation)` as
# a plain instance method never has it called, so it cannot demonstrate anything.
class TestUserRun < Plutonium::Interaction::AsyncRun
  def perform_on(record) = record
end
