# frozen_string_literal: true

module Plutonium
  module Kanban
    Action = Data.define(:key, :interaction, :on, :label, :icon, :confirmation)
  end
end
