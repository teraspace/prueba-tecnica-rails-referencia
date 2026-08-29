class LineItemDirective < ApplicationRecord
  DIRECTIVE_TYPES = %w[header unit].freeze
  SOURCES = %w[user resolution preserved default].freeze

  validates :line_item_id, :directive_type, :key, :source, :version, presence: true
  validates :directive_type, inclusion: { in: DIRECTIVE_TYPES }
  validates :source, inclusion: { in: SOURCES }
  validates :unit_uid, presence: true, if: -> { directive_type == "unit" }
  validates :unit_uid, absence: true, if: -> { directive_type == "header" }
end
