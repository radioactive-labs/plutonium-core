module Plutonium
  class Icons
    ICON_CACHE = {}
    ICON_SIZES = {
      sm: "w-3 h-3",
      md: "w-4 h-4",
      lg: "w-6 h-6"
    }

    class << self
      def render(name, size: :md)
        # This is not threadsafe, but should not cause any issues
        # I believe adding a mutex would be overall more expensive than a few potential
        # concurrent disk accesses for a brief while after boot.
        size = ICON_SIZES.key?(size) ? size : :sm
        ICON_CACHE["#{name}:#{size}"] ||= begin
          path = File.join __dir__, "icons/#{name}.svg"
          raise "Invalid icon: #{name}" unless File.exist?(path)

          File.read(path).sub("<svg ", "<svg class=\"#{ICON_SIZES[size]}\" ")
        end
      end
    end
  end
end
