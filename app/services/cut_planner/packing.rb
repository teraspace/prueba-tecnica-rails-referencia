class CutPlanner
  class Packing
    BarState = Struct.new(
      :stock_id,
      :stock_index,
      :instance,
      :length,
      :usable_length,
      :remaining,
      :pieces,
      keyword_init: true
    )

    def initialize(input)
      @input = input
    end

    def call
      states = []
      unplaced = {}

      expanded_pieces.each do |piece|
        required = piece.length + @input.config.fetch(:kerf)
        bar = best_fit_bar(states, required) || open_best_fit_bar(states, required)

        if bar
          bar.remaining -= required
          bar.pieces << piece
        else
          unplaced[piece.source_index] ||= { length: piece.length, quantity: 0 }
          unplaced[piece.source_index][:quantity] += 1
        end
      end

      {
        bars: states.map { |state| build_bar_plan(state) },
        unplaced: build_unplaced(unplaced)
      }
    end

    private

    def expanded_pieces
      @input.pieces.flat_map do |piece|
        (1..piece.quantity).map do |unit_index|
          Result::PieceAssignment.new(
            length: piece.length,
            source_index: piece.source_index,
            unit_index: unit_index
          )
        end
      end.sort_by { |piece| [-piece.length, piece.source_index, piece.unit_index] }
    end

    def best_fit_bar(states, required)
      states
        .select { |state| state.remaining >= required }
        .min_by { |state| [state.remaining - required, state.stock_index, state.instance] }
    end

    def open_best_fit_bar(states, required)
      available = @input.stock.select do |stock_type|
        stock_type.available > states.count { |state| state.stock_id == stock_type.id } &&
          usable_length(stock_type) >= required
      end
      stock_type = available.min_by { |candidate| [usable_length(candidate), candidate.source_index] }
      return unless stock_type

      instance = states.count { |state| state.stock_id == stock_type.id } + 1
      state = BarState.new(
        stock_id: stock_type.id,
        stock_index: stock_type.source_index,
        instance: instance,
        length: stock_type.length,
        usable_length: usable_length(stock_type),
        remaining: usable_length(stock_type),
        pieces: []
      )
      states << state
      state
    end

    def usable_length(stock_type)
      stock_type.length - @input.config.fetch(:head_trim) - @input.config.fetch(:tail_trim)
    end

    def build_bar_plan(state)
      Result::BarPlan.new(
        stock_id: state.stock_id,
        instance: state.instance,
        length: state.length,
        usable_length: state.usable_length,
        pieces: state.pieces,
        leftover: state.remaining,
        waste: state.length - state.pieces.sum(&:length)
      )
    end

    def build_unplaced(unplaced)
      unplaced.sort_by { |source_index, _| source_index }.map do |source_index, item|
        Result::UnplacedPiece.new(
          length: item.fetch(:length),
          quantity: item.fetch(:quantity),
          source_index: source_index
        )
      end
    end
  end
end
