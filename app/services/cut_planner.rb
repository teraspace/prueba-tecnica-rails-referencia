class CutPlanner
  def self.call(...)
    new(...).call
  end

  def initialize(pieces:, stock:, config:, strategy: Strategies::BestFitDecreasing)
    @input = Input.new(pieces: pieces, stock: stock, config: config)
    @strategy = strategy
  end

  def call
    packed = @strategy.new(@input).call
    Result::Plan.new(
      bars: packed.fetch(:bars),
      unplaced: packed.fetch(:unplaced),
      waste_ratio: Metrics.waste_ratio(packed.fetch(:bars))
    )
  end
end
