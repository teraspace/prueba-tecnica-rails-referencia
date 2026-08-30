module EffectiveConfig
  class Input
    attr_reader :line_item_id, :unit_uids, :version, :keys

    def initialize(line_item_id:, unit_uids:, version:, keys: nil)
      @line_item_id = Integer(line_item_id)
      @unit_uids = validate_unit_uids(unit_uids)
      @version = Integer(version)
      @keys = validate_keys(keys)
      raise ArgumentError, "version must be non-negative" if @version.negative?
    rescue ArgumentError, TypeError
      raise ArgumentError, "line_item_id and version must be integers and unit_uids must be strings"
    end

    private

    def validate_unit_uids(value)
      raise ArgumentError, "unit_uids must be an Array" unless value.is_a?(Array)
      value.map do |uid|
        raise ArgumentError, "unit_uids must contain strings" unless uid.is_a?(String)
        raise ArgumentError, "unit_uid cannot be blank" if uid.empty?
        uid
      end.uniq
    end

    def validate_keys(value)
      return nil if value.nil?
      raise ArgumentError, "keys must be an Array or nil" unless value.is_a?(Array)
      value.map do |key|
        raise ArgumentError, "keys must contain strings" unless key.is_a?(String)
        raise ArgumentError, "key cannot be blank" if key.empty?
        key
      end.uniq
    end
  end
end
