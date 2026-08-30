module EffectiveConfig
  class DirectiveQuery
    USER_INTENT_KEYS = %w[glass_type color_id finish_id coating low_e].freeze

    def initialize(input)
      @input = input
    end

    def call
      ActiveRecord::Base.connection.select_all(
        sql,
        "EffectiveConfigResolver",
        binds
      ).to_a
    end

    private

    def sql
      <<~SQL
        WITH eligible AS (
          SELECT id, directive_type, unit_uid, key, value, source, version, created_at
          FROM line_item_directives
          WHERE line_item_id = $1
            AND version <= $2
            AND (directive_type = 'header' OR unit_uid = ANY($3::varchar[]))
            AND ($4::varchar[] IS NULL OR key = ANY($4::varchar[]))
        ), ranked AS (
          SELECT eligible.*,
                 ROW_NUMBER() OVER (
                   PARTITION BY directive_type, unit_uid, key
                   ORDER BY CASE
                     WHEN key = ANY($5::varchar[]) AND source = 'user' THEN 0
                     ELSE 1
                   END, version DESC, created_at DESC, id DESC
                 ) AS rank_position
          FROM eligible
        )
        SELECT directive_type, unit_uid, key, value
        FROM ranked
        WHERE rank_position = 1
      SQL
    end

    def binds
      [
        bind("line_item_id", @input.line_item_id, ActiveRecord::Type::Integer.new),
        bind("version", @input.version, ActiveRecord::Type::Integer.new),
        bind("unit_uids", @input.unit_uids, string_array_type),
        bind("keys", @input.keys, string_array_type),
        bind("user_intent_keys", USER_INTENT_KEYS, string_array_type)
      ]
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
end
