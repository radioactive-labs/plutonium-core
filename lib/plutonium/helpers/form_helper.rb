require "view_component/form"

module Plutonium
  module Helpers
    module FormHelper
      include ActionView::Helpers::FormHelper

      def resource_form_for(record, options = {}, &block)
        options[:builder] ||= Plutonium::UI::FormBuilder
        options[:wrapper] ||= :default_resource_form
        options[:html] ||= {}
        unless options[:html].key?(:novalidate)
          options[:html][:novalidate] = false
        end

        with_resource_form_field_error_proc do
          form_for(record, options, &block)
        end
      end

      def token_tag(...)
        # needed to workaround https://github.com/tailwindlabs/tailwindcss/issues/3350
        super(...).sub(" />", " hidden />").html_safe
      end

      private

      def with_resource_form_field_error_proc
        # borrowed from https://github.com/heartcombo/simple_form/blob/main/lib/simple_form/action_view_extensions/form_helper.rb#L40C1-L50C10
        # this does not look threadsafe
        default_field_error_proc = ::ActionView::Base.field_error_proc
        begin
          ::ActionView::Base.field_error_proc = proc { |html_tag, instance| html_tag }
          yield
        ensure
          ::ActionView::Base.field_error_proc = default_field_error_proc
        end
      end
    end
  end
end
