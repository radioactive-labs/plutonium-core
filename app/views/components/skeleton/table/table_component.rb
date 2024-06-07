module PlutoniumUi::Skeleton
  class TableComponent < PlutoniumUi::Base
  end
end

Plutonium::ComponentRegistry.register :skeleton__table, to: PlutoniumUi::Skeleton::TableComponent
