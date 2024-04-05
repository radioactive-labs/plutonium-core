module Plutonium::Ui::Skeleton
  class TableComponent < Plutonium::Ui::Base
  end
end

Plutonium::ComponentRegistry.register :skeleton__table, to: Plutonium::Ui::Skeleton::TableComponent
