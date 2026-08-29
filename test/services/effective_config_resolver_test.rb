require "test_helper"

class EffectiveConfigResolverTest < ActiveSupport::TestCase
  def setup
    LineItemDirective.delete_all
  end

  test "resolves the latest directive and uses id as deterministic tie breaker" do
    same_time = Time.utc(2026, 1, 1, 12, 0, 0)
    create_directive(key: "width", value: "1000", version: 2, created_at: same_time)
    create_directive(key: "width", value: "1100", version: 2, created_at: same_time)

    result = resolve(version: 2)

    assert_equal "1100", result.fetch("unit-a").fetch("width")
  end

  test "inherits header when a unit has no directive for the key" do
    create_directive(directive_type: "header", key: "finish_id", value: "matte", source: "default")

    result = resolve(unit_uids: %w[unit-a unit-b])

    assert_equal "matte", result.fetch("unit-a").fetch("finish_id")
    assert_equal "matte", result.fetch("unit-b").fetch("finish_id")
  end

  test "user wins over a later resolution for an intent key" do
    create_directive(
      directive_type: "unit",
      key: "color_id",
      value: "red",
      source: "user",
      version: 2
    )
    create_directive(
      directive_type: "unit",
      key: "color_id",
      value: "blue",
      source: "resolution",
      version: 5
    )

    assert_equal "red", resolve(version: 5).fetch("unit-a").fetch("color_id")
  end

  test "resolution wins over a later user directive for a dimensional key" do
    create_directive(
      directive_type: "unit",
      key: "width",
      value: "1000",
      source: "user",
      version: 2
    )
    create_directive(
      directive_type: "unit",
      key: "width",
      value: "1200",
      source: "resolution",
      version: 5
    )

    assert_equal "1200", resolve(version: 5).fetch("unit-a").fetch("width")
  end

  test "a unit directive prevents header inheritance, including a nil value" do
    create_directive(directive_type: "header", key: "coating", value: "clear", source: "default")
    create_directive(directive_type: "unit", key: "coating", value: nil, source: "user", version: 2)

    result = resolve(version: 2)

    assert result.fetch("unit-a").key?("coating")
    assert_nil result.fetch("unit-a").fetch("coating")
  end

  test "keys filters inside the query and limits the result" do
    create_directive(key: "color_id", value: "red")
    create_directive(key: "width", value: "1200")

    statements = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      statements << payload[:sql] if payload[:name] == "EffectiveConfigResolver"
    end

    result = nil
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      result = resolve(keys: ["color_id"])
    end

    assert_equal 1, statements.length
    assert_includes statements.first, "$4::varchar[]"
    assert_equal({ "color_id" => "red" }, result.fetch("unit-a"))
  end

  test "empty inputs return one empty map per requested unit without querying" do
    statements = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      statements << payload[:sql] if payload[:name] == "EffectiveConfigResolver"
    end

    result = nil
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      result = resolve(unit_uids: %w[unit-a unit-b], keys: [])
    end

    assert_equal({ "unit-a" => {}, "unit-b" => {} }, result)
    assert_empty statements
  end

  test "one invocation uses one database query" do
    3.times do |index|
      create_directive(unit_uid: "unit-#{index}", key: "color_id", value: "#{index}")
    end

    statements = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      statements << payload[:sql] if payload[:name] == "EffectiveConfigResolver"
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      resolve(unit_uids: ["unit-0", "unit-1", "unit-2"])
    end

    assert_operator statements.length, :<=, 3
    assert_equal 1, statements.length
  end

  private

  def resolve(unit_uids: ["unit-a"], version: 10, keys: nil)
    EffectiveConfigResolver.call(
      line_item_id: 1,
      unit_uids: unit_uids,
      version: version,
      keys: keys
    )
  end

  def create_directive(
    directive_type: "unit",
    unit_uid: "unit-a",
    key: "color_id",
    value: "value",
    source: "default",
    version: 1,
    created_at: Time.utc(2026, 1, 1, 12, 0, 0)
  )
    LineItemDirective.create!(
      line_item_id: 1,
      directive_type: directive_type,
      unit_uid: directive_type == "header" ? nil : unit_uid,
      key: key,
      value: value,
      source: source,
      version: version,
      created_at: created_at
    )
  end
end
