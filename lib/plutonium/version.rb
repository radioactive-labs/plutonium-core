module Plutonium
  VERSION = "0.23.0"
  NEXT_MAJOR_VERSION = VERSION.split(".").tap { |v|
    v[1] = v[1].to_i + 1
    v[2] = 0
  }.join(".")
end
