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
    EffectiveConfig::ResultBuilder.new(@input).call(rows)
  end

  private

  def empty_result
    @input.unit_uids.to_h { |unit_uid| [unit_uid, {}] }
  end

end
