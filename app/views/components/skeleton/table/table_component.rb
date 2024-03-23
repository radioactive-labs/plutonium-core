module Plutonium::UI::Skeleton
  class TableComponent < Plutonium::UI::Base
  end
end

Plutonium::ComponentRegistry.register :skeleton__table, to: Plutonium::UI::Skeleton::TableComponent
