class CutPlanner
  PieceRequest = Struct.new(:length, :quantity, :source_index, keyword_init: true) do
    def initialize(**attributes)
      super
      freeze
    end
  end

  StockType = Struct.new(:id, :length, :available, :source_index, keyword_init: true) do
    def initialize(**attributes)
      super
      freeze
    end
  end

  PieceAssignment = Struct.new(:length, :source_index, :unit_index, keyword_init: true) do
    def initialize(**attributes)
      super
      freeze
    end
  end

  UnplacedPiece = Struct.new(:length, :quantity, :source_index, keyword_init: true) do
    def initialize(**attributes)
      super
      freeze
    end
  end

  BarPlan = Struct.new(
    :stock_id,
    :instance,
    :length,
    :usable_length,
    :pieces,
    :leftover,
    :waste,
    keyword_init: true
  ) do
    def initialize(**attributes)
      attributes[:pieces] = attributes.fetch(:pieces).freeze
      super
      freeze
    end
  end

  Plan = Struct.new(:bars, :unplaced, :waste_ratio, keyword_init: true) do
    def initialize(**attributes)
      attributes[:bars] = attributes.fetch(:bars).freeze
      attributes[:unplaced] = attributes.fetch(:unplaced).freeze
      super
      freeze
    end
  end

  def initialize(pieces:, stock:, config:)
    @pieces = normalize_pieces(pieces)
    @stock = normalize_stock(stock)
    @config = normalize_config(config)
  end

  def call
    raise NotImplementedError, "cut planning algorithm is implemented in the next phase"
  end

  private

  attr_reader :pieces, :stock, :config

  def normalize_pieces(value)
    raise ArgumentError, "pieces must be an Array" unless value.is_a?(Array)

    value.each_with_index.map do |piece, index|
      raise ArgumentError, "each piece must be a Hash" unless piece.respond_to?(:fetch)

      PieceRequest.new(
        length: positive_finite_number(piece.fetch(:length)),
        quantity: positive_integer(piece.fetch(:quantity)),
        source_index: index
      )
    end.freeze
  rescue KeyError, TypeError
    raise ArgumentError, "each piece needs length and quantity"
  end

  def normalize_stock(value)
    raise ArgumentError, "stock must be an Array" unless value.is_a?(Array)

    seen_ids = {}
    value.each_with_index.map do |bar, index|
      raise ArgumentError, "each stock item must be a Hash" unless bar.respond_to?(:fetch)

      id = bar.fetch(:id)
      raise ArgumentError, "stock ids must be non-empty strings" unless id.is_a?(String) && !id.empty?
      raise ArgumentError, "stock ids must be unique" if seen_ids[id]

      seen_ids[id] = true
      StockType.new(
        id: id,
        length: positive_finite_number(bar.fetch(:length)),
        available: non_negative_integer(bar.fetch(:available)),
        source_index: index
      )
    end.freeze
  rescue KeyError, TypeError
    raise ArgumentError, "each stock item needs id, length and available"
  end

  def normalize_config(value)
    raise ArgumentError, "config must be a Hash" unless value.respond_to?(:fetch)

    {
      kerf: non_negative_finite_number(value.fetch(:kerf)),
      head_trim: non_negative_finite_number(value.fetch(:head_trim)),
      tail_trim: non_negative_finite_number(value.fetch(:tail_trim))
    }.freeze
  rescue KeyError, TypeError
    raise ArgumentError, "config needs kerf, head_trim and tail_trim"
  end

  def positive_integer(value)
    integer = Integer(value)
    raise ArgumentError, "quantity must be positive" unless integer.positive?

    integer
  rescue ArgumentError, TypeError
    raise ArgumentError, "quantity must be a positive integer"
  end

  def non_negative_integer(value)
    integer = Integer(value)
    raise ArgumentError, "available cannot be negative" if integer.negative?

    integer
  rescue ArgumentError, TypeError
    raise ArgumentError, "available must be a non-negative integer"
  end

  def positive_finite_number(value)
    number = Float(value)
    raise ArgumentError, "number must be finite and positive" unless number.finite? && number.positive?

    number
  rescue ArgumentError, TypeError
    raise ArgumentError, "number must be finite and positive"
  end

  def non_negative_finite_number(value)
    number = Float(value)
    raise ArgumentError, "number must be finite and non-negative" unless number.finite? && number >= 0

    number
  rescue ArgumentError, TypeError
    raise ArgumentError, "number must be finite and non-negative"
  end
end
