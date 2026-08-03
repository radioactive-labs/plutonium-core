class LocusPortal::UserPolicy < ::UserPolicy
  include LocusPortal::ResourcePolicy

  # locus_portal registers User as a SINGULAR resource and has no entity scoping
  # at all, so the base policy's scope is every user in the system. A singular
  # route carries no :id, so the scope has to identify exactly one record — see
  # OrgPortal::UserPolicy for the same reasoning, and
  # Plutonium::SingularScopeError for what it costs when it doesn't hold.
  relation_scope do |relation|
    default_relation_scope(relation).where(id: user.id)
  end
end
