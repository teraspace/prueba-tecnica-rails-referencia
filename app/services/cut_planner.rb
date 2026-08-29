class CutPlanner
  def self.call(...)
    new(...).call
  end

  def initialize(pieces:, stock:, config:)
    @input = Input.new(pieces: pieces, stock: stock, config: config)
  end

  def call
    packed = Packing.new(@input).call
    Result::Plan.new(
      bars: packed.fetch(:bars),
      unplaced: packed.fetch(:unplaced),
      waste_ratio: Metrics.waste_ratio(packed.fetch(:bars))
    )
  end
end
