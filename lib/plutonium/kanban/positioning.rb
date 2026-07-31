# frozen_string_literal: true

require "plutonium/positioning"

module Plutonium
  module Kanban
    # Kanban's positioning strategy is the framework-wide one — see
    # Plutonium::Positioning::Config. This alias preserves the original
    # namespace so `position_on` and every existing reference keep working.
    module Positioning
      Config = Plutonium::Positioning::Config
      Move = Plutonium::Positioning::Move
    end
  end
end
