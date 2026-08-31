class EffectiveConfigResolver
  USER_INTENT_KEYS = %w[glass_type color_id finish_id coating low_e].freeze
  DIMENSIONAL_KEYS = %w[width height dlo_width dlo_height].freeze

  def self.call(...)
    new(...).call
  end

  def initialize(line_item_id:, unit_uids:, version:, keys: nil)
    @input = EffectiveConfig::Input.new(line_item_id:, unit_uids:, version:, keys:)
  end

  def call
    return empty_result if @input.unit_uids.empty? || @input.keys&.empty?

    rows = fetch_winning_directives
    build_result(rows)
  end

  private

  def empty_result
    @input.unit_uids.to_h { |unit_uid| [unit_uid, {}] }
  end

  def fetch_winning_directives
    sql = <<~SQL
      WITH eligible AS (
        SELECT id, directive_type, unit_uid, key, value, source, version, created_at
        FROM line_item_directives
        WHERE line_item_id = $1
          AND version <= $2
          AND (
            directive_type = 'header'
            OR unit_uid = ANY($3::varchar[])
          )
          AND ($4::varchar[] IS NULL OR key = ANY($4::varchar[]))
      ), ranked AS (
        SELECT eligible.*,
               ROW_NUMBER() OVER (
                 PARTITION BY directive_type, unit_uid, key
                 ORDER BY
                   CASE
                     WHEN key = ANY($5::varchar[]) AND source = 'user' THEN 0
                     ELSE 1
                   END,
                   version DESC,
                   created_at DESC,
                   id DESC
               ) AS rank_position
        FROM eligible
      )
      SELECT directive_type, unit_uid, key, value
      FROM ranked
      WHERE rank_position = 1
    SQL

    binds = [
      bind("line_item_id", @input.line_item_id, ActiveRecord::Type::Integer.new),
      bind("version", @input.version, ActiveRecord::Type::Integer.new),
      bind("unit_uids", @input.unit_uids, string_array_type),
      bind("keys", @input.keys, string_array_type),
      bind("user_intent_keys", USER_INTENT_KEYS, string_array_type)
    ]

    ActiveRecord::Base.connection.select_all(
      sql,
      "EffectiveConfigResolver",
      binds
    ).to_a
  end

  def build_result(rows)
    headers = {}
    units = Hash.new { |hash, unit_uid| hash[unit_uid] = {} }

    rows.each do |row|
      if row["directive_type"] == "header"
        headers[row["key"]] = row["value"]
      else
        units[row["unit_uid"]][row["key"]] = row["value"]
      end
    end

    @input.unit_uids.to_h do |unit_uid|
      effective = headers.merge(units.fetch(unit_uid, {}))
      effective.select! { |key, _value| @input.keys.nil? || @input.keys.include?(key) }
      [unit_uid, effective]
    end
  end

  def bind(name, value, type)
    ActiveRecord::Relation::QueryAttribute.new(name, value, type)
  end

  def string_array_type
    @string_array_type ||= ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(
      ActiveRecord::Type::String.new
    )
  end
end
