module Plutonium
  module Helpers
    module MenuHelper
      # <ul class="list-unstyled ps-0">
      #   <li class="mb-1">
      #     <button class="btn btn-toggle d-inline-flex align-items-center rounded border-0 collapsed" data-bs-toggle="collapse" data-bs-target="#resources-collapse" aria-expanded="true">Resources</button>
      #     <div class="collapse show" id="resources-collapse">
      #         <ul class="btn-toggle-nav list-unstyled fw-normal pb-1 small">
      #           <li class="mb-1">
      #             <a class="link-body-emphasis d-inline-flex text-decoration-none rounded" data-turbo-frame="content" href="http://127.0.0.1:3000/admin/organisations">Organisations</a>
      #           </li>
      #           <li class="mb-1" style="margin-left: 1.25em">
      #             <button class="btn btn-toggle d-inline-flex align-items-center rounded border-0 collapsed" data-bs-toggle="collapse" data-bs-target="#nested-collapse" aria-expanded="true">Nested</button>
      #             <div class="collapse show" id="nested-collapse">
      #               <ul class="btn-toggle-nav list-unstyled fw-normal pb-1 small">
      #                   <li class="mb-1">
      #                     <a class="link-body-emphasis d-inline-flex text-decoration-none rounded" data-turbo-frame="content" href="http://127.0.0.1:3000/admin/organisations">Nested Organisations</a>
      #                   </li>
      #               </ul>
      #             </div>
      #           </li>
      #         </ul>
      #     </div>
      #   </li>
      # </ul>

      def build_sidebar_menu(menu, turbo_frame: "content")
        tag.ul class: "list-unstyled ps-0" do
          menu.each do |name, definition|
            concat build_sidebar_menu_item(name, definition, 0)
          end
        end
      end

      private

      def build_sidebar_menu_item(name, definition, depth)
        if definition.is_a? String
          tag.li class: "mb-1" do
            tag.a name,
              class: "link-body-emphasis d-inline-flex text-decoration-none rounded ps-0",
              data: {turbo_frame: "content"},
              href: definition
          end
        else
          style = "margin-left: #{depth * 1.25}em"
          tag.li(class: "mb-1", style:) do
            concat tag.button(
              name,
              class: "btn btn-toggle d-inline-flex align-items-center rounded border-0 collapsed ps-0",
              data: {bs_toggle: "collapse", bs_target: "##{name.parameterize}-collapse"},
              aria: {expanded: "false"}
            )

            concat begin
              tag.div(class: "collapse", id: "#{name.parameterize}-collapse") do
                tag.ul(class: "btn-toggle-nav list-unstyled fw-normal pb-1 small") do
                  definition.each do |name, sub_definition|
                    concat build_sidebar_menu_item(name, sub_definition, depth + 1)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
