class EffectiveConfigResolver
  def self.call(...)
    new(...).call
  end

  def initialize(line_item_id:, unit_uids:, version:, keys: nil)
    @input = EffectiveConfig::Input.new(line_item_id:, unit_uids:, version:, keys:)
  end

  def call
    return empty_result if @input.unit_uids.empty? || @input.keys&.empty?

    rows = EffectiveConfig::DirectiveQuery.new(@input).call
    build_result(rows)
  end

  private

  def empty_result
    @input.unit_uids.to_h { |unit_uid| [unit_uid, {}] }
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

end
