module Plutonium::UI
  class Button < Plutonium::UI::Base
    option :label
    option :to, optional: true
    option :icon, optional: true
    option :color, optional: true
    option :variant, optional: true
    option :size, optional: true

    private

    def classnames
      classnames = [classes]
      classnames << "me-2 text-center py-2.5 font-medium px-5"
      classnames << "inline-flex items-center justify-center" if icon.present?
      classnames << color_classes
      classnames << shape_classes
      classnames << size_classes
      classnames.join " "
    end

    def color_classes
      case variant
      when :outline
        outline_color_classes
      when :link
        link_color_classes
      else
        default_color_classes
      end
    end

    def shape_classes
      case variant
      when :link
        nil
      when :pill
        "rounded-full focus:outline-none focus:ring-4"
      else
        "rounded-lg focus:outline-none focus:ring-4"
      end
    end

    def size_classes
      case size
      when :xs
        "text-xs"
      when :lg
        "text-base"
      when :xl
        "py-3.5 text-base"
      else
        "text-sm"
      end
    end

    def outline_color_classes
      case color
      when :primary
        "border border-primary-700 text-primary-700 hover:bg-primary-800 hover:text-white focus:ring-primary-300 dark:border-primary-500 dark:text-primary-600 dark:hover:bg-primary-500 dark:hover:text-white dark:focus:ring-primary-800"
      when :blue
        "border border-blue-700 text-blue-700 hover:bg-blue-800 hover:text-white focus:ring-blue-300 dark:border-blue-500 dark:text-blue-500 dark:hover:bg-blue-500 dark:hover:text-white dark:focus:ring-blue-800"
      when :green
        "border border-green-700 text-green-700 hover:bg-green-800 hover:text-white focus:ring-green-300 dark:border-green-500 dark:text-green-500 dark:hover:bg-green-600 dark:hover:text-white dark:focus:ring-green-800"
      when :red
        "border border-red-700 text-red-700 hover:bg-red-800 hover:text-white focus:ring-red-300 dark:border-red-500 dark:text-red-500 dark:hover:bg-red-600 dark:hover:text-white dark:focus:ring-red-900"
      when :yellow
        "border border-yellow-400 text-yellow-400 hover:bg-yellow-500 hover:text-white focus:ring-yellow-300 dark:border-yellow-300 dark:text-yellow-300 dark:hover:bg-yellow-400 dark:hover:text-white dark:focus:ring-yellow-900"
      when :purple
        "border border-purple-700 text-purple-700 hover:bg-purple-800 hover:text-white focus:ring-purple-300 dark:border-purple-400 dark:text-purple-400 dark:hover:bg-purple-500 dark:hover:text-white dark:focus:ring-purple-900"
      when :dark
        "border border-gray-800 text-gray-900 hover:bg-gray-900 hover:text-white focus:ring-gray-300 dark:border-gray-600 dark:text-gray-400 dark:hover:bg-gray-600 dark:hover:text-white dark:focus:ring-gray-800 "
      when :light
        "border border-gray-300 bg-white text-gray-900 hover:bg-gray-100 focus:ring-gray-100 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:hover:border-gray-600 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
      else
        "border border-gray-200 bg-white text-gray-900 hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-gray-100 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white dark:focus:ring-gray-700"
      end
    end

    def link_color_classes
      case color
      when :primary
        "text-primary-600 dark:text-primary-500 hover:underline text-primary-600 dark:text-primary-500 hover:underline"
      when :blue
        "text-blue-600 dark:text-blue-500 hover:underline text-blue-600 dark:text-blue-500 hover:underline"
      when :green
        "text-green-600 dark:text-green-500 hover:underline text-green-600 dark:text-green-500 hover:underline"
      when :red
        "text-red-600 dark:text-red-500 hover:underline text-red-600 dark:text-red-500 hover:underline"
      when :yellow
        "text-yellow-600 dark:text-yellow-500 hover:underline text-yellow-600 dark:text-yellow-500 hover:underline"
      when :purple
        "text-purple-600 dark:text-purple-500 hover:underline text-purple-600 dark:text-purple-500 hover:underline"
      else
        "text-gray-800 dark:text-gray-900 hover:underline text-gray-600 dark:text-gray-900 hover:underline"
      end
    end

    def default_color_classes
      case color
      when :primary
        "bg-primary-700 text-white hover:bg-primary-800 focus:ring-primary-300 dark:bg-primary-600 dark:hover:bg-primary-700 dark:focus:ring-primary-800"
      when :blue
        "bg-blue-700 text-white hover:bg-blue-800 focus:ring-blue-300 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800"
      when :green
        "bg-green-700 text-white hover:bg-green-800 focus:ring-green-300 dark:bg-green-600 dark:hover:bg-green-700 dark:focus:ring-green-800"
      when :red
        "bg-red-700 text-white hover:bg-red-800 focus:ring-red-300 dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-900"
      when :yellow
        "bg-yellow-400 text-white hover:bg-yellow-500 focus:ring-yellow-300 dark:focus:ring-yellow-900"
      when :purple
        "bg-purple-700 text-white hover:bg-purple-800 focus:ring-purple-300 dark:bg-purple-600 dark:hover:bg-purple-700 dark:focus:ring-purple-900"
      when :dark
        "bg-gray-800 text-white hover:bg-gray-900 focus:ring-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
      when :light
        "border border-gray-300 bg-white text-gray-900 hover:bg-gray-100 focus:ring-gray-100 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:hover:border-gray-600 dark:hover:bg-gray-700 dark:focus:ring-gray-700"
      else
        "border border-gray-200 bg-white text-gray-900 hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-gray-100 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white dark:focus:ring-gray-700"
      end
    end
  end
end

Plutonium::ComponentRegistry.register :button, to: Plutonium::UI::Button
