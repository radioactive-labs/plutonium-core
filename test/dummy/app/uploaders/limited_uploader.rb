# frozen_string_literal: true

# A Shrine uploader with an explicit size validation, used to exercise wizard
# STAGE-PHASE attachment validation (`uploader:` on a file field). The dummy's base
# Shrine deliberately omits the `validation` plugin, so this subclass loads
# `validation_helpers` itself — proving a per-field uploader's validations are
# enforced on the step even when the global Shrine has none.
class LimitedUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 1024, message: "is too large (max 1 KB)"
  end
end
