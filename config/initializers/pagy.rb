require "pagy"
require "pagy/toolbox/helpers/support/series"

# Allow clients to override the page size via the `limit` param.
# Without this, Pagy::Request#resolve_limit ignores the param entirely.
Pagy::OPTIONS[:max_limit] = 100
