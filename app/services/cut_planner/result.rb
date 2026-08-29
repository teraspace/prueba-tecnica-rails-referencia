class CutPlanner
  module Result
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
  end
end
