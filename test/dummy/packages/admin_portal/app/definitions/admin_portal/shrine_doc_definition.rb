class AdminPortal::ShrineDocDefinition < ::ResourceDefinition
  include AdminPortal::ResourceDefinition

  # A plain server-side file input (no direct_upload) backed by active_shrine —
  # the submitted value is a single-read Rack upload. Exercises that resource
  # param extraction doesn't consume it before create/update reads it.
  field :title
  input :file, as: :file
end
