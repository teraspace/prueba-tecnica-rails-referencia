class CreateLineItemDirectives < ActiveRecord::Migration[7.2]
  def change
    create_table :line_item_directives do |t|
      t.bigint :line_item_id, null: false
      t.string :directive_type, limit: 10, null: false
      t.string :unit_uid, limit: 64
      t.string :key, limit: 64, null: false
      t.text :value
      t.string :source, limit: 16, null: false
      t.integer :version, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_check_constraint :line_item_directives,
      "directive_type IN ('header', 'unit')",
      name: "line_item_directives_directive_type_check"

    add_check_constraint :line_item_directives,
      "source IN ('user', 'resolution', 'preserved', 'default')",
      name: "line_item_directives_source_check"

    add_check_constraint :line_item_directives,
      "(directive_type = 'header' AND unit_uid IS NULL) OR " \
        "(directive_type = 'unit' AND unit_uid IS NOT NULL)",
      name: "line_item_directives_unit_uid_check"

    add_index :line_item_directives,
      [:line_item_id, :key, :version, :created_at, :id],
      order: { version: :desc, created_at: :desc, id: :desc },
      where: "directive_type = 'header'",
      name: "idx_directives_header_lookup"

    add_index :line_item_directives,
      [:line_item_id, :unit_uid, :key, :version, :created_at, :id],
      order: { version: :desc, created_at: :desc, id: :desc },
      where: "directive_type = 'unit'",
      name: "idx_directives_unit_lookup"
  end
end
