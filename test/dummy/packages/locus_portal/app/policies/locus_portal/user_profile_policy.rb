class LocusPortal::UserProfilePolicy < ::UserProfilePolicy
  include LocusPortal::ResourcePolicy

  # Same reasoning as LocusPortal::UserPolicy: registered singular, portal has no
  # entity scoping, so the base scope is every profile. Narrowed to the viewer's
  # own, which is what a singular profile route means.
  relation_scope do |relation|
    default_relation_scope(relation).where(user_id: user.id)
  end
end
