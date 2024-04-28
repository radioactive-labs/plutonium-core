require "zeitwerk"

loader = Zeitwerk::Loader.for_gem # (warn_on_extra_files: false)
loader.setup

module PlutoniumGenerators
end
