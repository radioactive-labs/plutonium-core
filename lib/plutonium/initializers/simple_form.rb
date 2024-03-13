require "simple_form"

# Register components
Dir.glob(Plutonium.lib_root.join("simple_form_components", "*.rb")) { |component| load component }

# Use this setup block to configure all options available in SimpleForm.
SimpleForm.setup do |config|
  # Disable country select
  # TODO: handle this in plutonium
  config.input_mappings = {/country/ => :select}

  config.wrappers :default_resource_form, class: "flex flex-col md:flex-row items-start space-y-2 md:space-y-0 md:space-x-2 mb-4" do |b|
    b.use :html5
    b.use :placeholder
    b.use :maxlength
    b.use :minlength
    b.optional :pattern
    b.use :min_max
    b.optional :readonly

    b.use :label, class: "md:w-1/6 mt-2 text-sm font-medium"

    b.wrapper tag: :div, html: {
      class: "md:w-5/6 w-full"
    } do |input|
      input.use :input, class: "w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-primary-500 focus:border-primary-500 font-medium text-sm dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white ",
        error_class: "bg-red-50 border border-red-500 text-red-900 placeholder-red-700 rounded-lg focus:ring-red-500 dark:bg-gray-700 focus:border-red-500 dark:text-red-500 dark:placeholder-red-500 dark:border-red-500",
        valid_class: "bg-green-50 border border-green-500 text-green-900 dark:text-green-400 placeholder-green-700 dark:placeholder-green-500 rounded-lg focus:ring-green-500 focus:border-green-500 dark:bg-gray-700 dark:border-green-500"
      input.use :full_error, wrap_with: {tag: "p", class: "mt-2 text-sm text-red-600 dark:text-red-500"}
      input.use :hint, wrap_with: {tag: "p", class: "mt-2 text-sm text-gray-500 dark:text-gray-400"}
    end
  end
end
