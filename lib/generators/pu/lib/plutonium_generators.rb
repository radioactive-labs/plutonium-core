require "zeitwerk"

loader = Zeitwerk::Loader.for_gem # (warn_on_extra_files: false)
loader.inflector.inflect(
  "cli" => "CLI"
)
loader.setup

module PlutoniumGenerators
  class << self
    def cli?
      ENV["PU_CLI"] == "1"
    end
  end
end
