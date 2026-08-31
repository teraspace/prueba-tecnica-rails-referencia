module EffectiveConfig
  class ResultBuilder
    def initialize(input)
      @input = input
    end

    def call(rows)
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
  end
end
