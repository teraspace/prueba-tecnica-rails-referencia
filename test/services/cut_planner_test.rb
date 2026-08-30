require "test_helper"

class CutPlannerTest < ActiveSupport::TestCase
  test "packs pieces while respecting trims and kerf" do
    plan = planner(
      pieces: [{ length: 1_450.0, quantity: 2 }, { length: 820.5, quantity: 3 }],
      stock: [{ id: "BAR-A", length: 6_000.0, available: 1 }],
      config: { kerf: 4.0, head_trim: 100.0, tail_trim: 50.0 }
    ).call

    assert_empty plan.unplaced
    assert_equal 1, plan.bars.length
    assert_equal 5, plan.bars.first.pieces.length
    assert_in_delta 468.5, plan.bars.first.leftover, 0.0001
    assert_in_delta 0.1064166667, plan.waste_ratio, 0.0001
  end

  test "reports pieces that exceed available inventory" do
    plan = planner(
      pieces: [{ length: 3_000.0, quantity: 2 }],
      stock: [{ id: "BAR-A", length: 5_000.0, available: 1 }],
      config: { kerf: 4.0, head_trim: 100.0, tail_trim: 50.0 }
    ).call

    assert_equal 1, plan.bars.first.pieces.length
    assert_equal [[3_000.0, 1, 0]], plan.unplaced.map { |item| [item.length, item.quantity, item.source_index] }
  end

  test "reports a piece longer than every useful bar" do
    plan = planner(
      pieces: [{ length: 4_900.0, quantity: 1 }],
      stock: [{ id: "BAR-A", length: 5_000.0, available: 1 }],
      config: { kerf: 0.0, head_trim: 100.0, tail_trim: 50.0 }
    ).call

    assert_empty plan.bars
    assert_equal [[4_900.0, 1]], plan.unplaced.map { |item| [item.length, item.quantity] }
  end

  test "kerf can change whether a second piece fits" do
    without_kerf = planner(
      pieces: [{ length: 500.0, quantity: 2 }],
      stock: [{ id: "BAR-A", length: 1_000.0, available: 1 }],
      config: { kerf: 0.0, head_trim: 0.0, tail_trim: 0.0 }
    ).call
    with_kerf = planner(
      pieces: [{ length: 500.0, quantity: 2 }],
      stock: [{ id: "BAR-A", length: 1_000.0, available: 1 }],
      config: { kerf: 1.0, head_trim: 0.0, tail_trim: 0.0 }
    ).call

    assert_empty without_kerf.unplaced
    assert_equal 1, with_kerf.unplaced.first.quantity
  end

  test "is deterministic for the same input" do
    input = {
      pieces: [{ length: 1_000.0, quantity: 3 }, { length: 600.0, quantity: 4 }],
      stock: [
        { id: "BAR-A", length: 2_000.0, available: 2 },
        { id: "BAR-B", length: 1_500.0, available: 2 }
      ],
      config: { kerf: 4.0, head_trim: 10.0, tail_trim: 10.0 }
    }

    first = CutPlanner.new(**input).call
    second = CutPlanner.new(**input).call

    assert_equal first.to_h, second.to_h
  end

  test "rejects invalid physical inputs" do
    assert_raises(ArgumentError) do
      planner(
        pieces: [{ length: 0, quantity: 1 }],
        stock: [],
        config: { kerf: 0, head_trim: 0, tail_trim: 0 }
      )
    end

    assert_raises(ArgumentError) do
      planner(
        pieces: [],
        stock: [{ id: "BAR-A", length: 1_000, available: -1 }],
        config: { kerf: 0, head_trim: 0, tail_trim: 0 }
      )
    end
  end

  test "preserves piece accounting and never exceeds useful capacity" do
    plan = planner(
      pieces: [{ length: 700.0, quantity: 3 }, { length: 350.0, quantity: 4 }],
      stock: [{ id: "BAR-A", length: 2_000.0, available: 2 }],
      config: { kerf: 5.0, head_trim: 50.0, tail_trim: 50.0 }
    ).call

    placed = plan.bars.sum { |bar| bar.pieces.length }
    not_placed = plan.unplaced.sum(&:quantity)
    assert_equal 7, placed + not_placed
    plan.bars.each do |bar|
      consumed = bar.pieces.sum { |piece| piece.length + 5.0 }
      assert_operator consumed, :<=, bar.usable_length + 0.0001
    end
    assert_operator plan.waste_ratio, :>=, 0.0
  end

  test "accepts a replaceable packing strategy" do
    strategy = Class.new do
      def initialize(_input); end

      def call
        { bars: [], unplaced: [] }
      end
    end

    plan = CutPlanner.new(
      pieces: [],
      stock: [],
      config: { kerf: 0, head_trim: 0, tail_trim: 0 },
      strategy: strategy
    ).call

    assert_empty plan.bars
    assert_empty plan.unplaced
  end

  private

  def planner(pieces:, stock:, config:)
    CutPlanner.new(pieces: pieces, stock: stock, config: config)
  end
end
