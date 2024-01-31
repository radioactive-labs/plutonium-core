module Plutonium
  module Helpers
    module MenuHelper
      def build_sidebar_menu(menu, turbo_frame: "content")
        tag.ul class: "list-unstyled ps-0" do
          separated = menu.delete :separated

          menu.each do |name, submenu|
            id = name.to_s.parameterize

            submenu.transform_values! { |v| URI.parse(v) }
            active = submenu.values.any? { |url| request.fullpath.starts_with? url.path }

            concat begin
              tag.li class: "mb-1" do
                concat(
                  tag.button(name,
                    class: "btn btn-toggle d-inline-flex align-items-center rounded border-0 collapsed",
                    data: {bs_toggle: "collapse", bs_target: "##{id}-collapse"},
                    aria: {expanded: active})
                )

                concat begin
                  tag.div class: "collapse #{"show" if active}", id: "#{id}-collapse" do
                    concat begin
                      tag.ul class: "btn-toggle-nav list-unstyled fw-normal pb-1 small" do
                        submenu.each do |name, link|
                          concat(
                            tag.li(
                              link_to(name, link.to_s,
                                class: "link-body-emphasis d-inline-flex text-decoration-none rounded",
                                data: {turbo_frame:}),
                              class: "mb-1"
                            )
                          )
                        end
                      end
                    end
                  end
                end
              end
            end
          end

          next if separated.blank?

          concat tag.li(class: "border-top my-3")

          separated.each do |name, link|
            concat begin
              tag.ul class: "btn-toggle-nav list-unstyled fw-normal pb-1 small" do
                concat(
                  tag.li(
                    link_to(name, link.to_s,
                      class: "link-body-emphasis d-inline-flex text-decoration-none rounded",
                      data: {turbo_frame:}),
                    class: "mb-1"
                  )
                )
              end
            end
          end
        end
      end
    end
  end
end
