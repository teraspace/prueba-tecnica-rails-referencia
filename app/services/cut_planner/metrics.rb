class CutPlanner
  module Metrics
    module_function

    def waste_ratio(bars)
      physical_material = bars.sum(&:length)
      productive_material = bars.sum { |bar| bar.pieces.sum(&:length) }
      waste = physical_material - productive_material
      physical_material.zero? ? 0.0 : waste / physical_material
    end
  end
end
