module Plutonium
  class Icons
    ICON_CACHE = {}
    ICON_SIZES = {
      sm: "w-3 h-3",
      md: "w-4 h-4",
      lg: "w-6 h-6",
      xl: "w-8 h-8"
    }

    class << self
      def render(name, size: :md, classname: nil)
        size = ICON_SIZES.key?(size) ? size : :sm
        classname = (Array(classname) + [ICON_SIZES[size]]).join(" ")

        resolve(name).sub("<svg ", "<svg class=\"#{classname}\" ").html_safe
      end

      def resolve(name)
        # This is not threadsafe, but should not cause any issues
        # I believe adding a mutex would be overall more expensive than a few potential
        # concurrent disk accesses for a brief while after boot.
        ICON_CACHE[name] ||= begin
          path = Plutonium.root.join "app/assets/icons/#{name}.svg"
          raise "Invalid icon: #{name}" unless File.exist?(path)

          File.read(path)
        end
      end
    end
  end
end
