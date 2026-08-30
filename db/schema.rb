# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_08_29_220255) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "line_item_directives", force: :cascade do |t|
    t.bigint "line_item_id", null: false
    t.string "directive_type", limit: 10, null: false
    t.string "unit_uid", limit: 64
    t.string "key", limit: 64, null: false
    t.text "value"
    t.string "source", limit: 16, null: false
    t.integer "version", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["line_item_id", "key", "version", "created_at", "id"], name: "idx_directives_header_lookup", order: { version: :desc, created_at: :desc, id: :desc }, where: "((directive_type)::text = 'header'::text)"
    t.index ["line_item_id", "unit_uid", "key", "version", "created_at", "id"], name: "idx_directives_unit_lookup", order: { version: :desc, created_at: :desc, id: :desc }, where: "((directive_type)::text = 'unit'::text)"
    t.check_constraint "directive_type::text = 'header'::text AND unit_uid IS NULL OR directive_type::text = 'unit'::text AND unit_uid IS NOT NULL", name: "line_item_directives_unit_uid_check"
    t.check_constraint "directive_type::text = ANY (ARRAY['header'::character varying::text, 'unit'::character varying::text])", name: "line_item_directives_directive_type_check"
    t.check_constraint "source::text = ANY (ARRAY['user'::character varying::text, 'resolution'::character varying::text, 'preserved'::character varying::text, 'default'::character varying::text])", name: "line_item_directives_source_check"
  end

  create_table "materials", force: :cascade do |t|
    t.string "code", limit: 32, null: false
    t.string "unit", limit: 8, null: false

    t.unique_constraint ["code"], name: "materials_code_key"
  end

  create_table "reservation_requests", force: :cascade do |t|
    t.bigint "production_order_id", null: false
    t.bigint "material_id", null: false
    t.decimal "quantity_required", precision: 14, scale: 4, null: false
    t.decimal "quantity_reserved", precision: 14, scale: 4, default: "0.0", null: false
    t.string "status", limit: 16, default: "pending", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.check_constraint "quantity_required > 0::numeric", name: "reservation_requests_quantity_required_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'fulfilled'::character varying, 'partial'::character varying, 'backordered'::character varying, 'failed'::character varying]::text[])", name: "reservation_requests_status_check"
  end

  create_table "stock_lots", force: :cascade do |t|
    t.bigint "material_id", null: false
    t.bigint "warehouse_id", null: false
    t.decimal "quantity", precision: 14, scale: 4, null: false
    t.timestamptz "received_at", null: false
    t.index ["material_id", "warehouse_id", "received_at", "id"], name: "idx_stock_lots_fifo"
    t.check_constraint "quantity >= 0::numeric", name: "stock_lots_quantity_check"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "request_id", null: false
    t.bigint "stock_lot_id", null: false
    t.decimal "quantity_moved", precision: 14, scale: 4, null: false
    t.timestamptz "moved_at", default: -> { "now()" }, null: false
    t.index ["request_id"], name: "idx_stock_movements_request"
    t.index ["stock_lot_id"], name: "idx_stock_movements_lot"
    t.check_constraint "quantity_moved > 0::numeric", name: "stock_movements_quantity_moved_check"
  end

  add_foreign_key "reservation_requests", "materials", name: "reservation_requests_material_id_fkey"
  add_foreign_key "stock_lots", "materials", name: "stock_lots_material_id_fkey"
  add_foreign_key "stock_movements", "reservation_requests", column: "request_id", name: "stock_movements_request_id_fkey"
  add_foreign_key "stock_movements", "stock_lots", name: "stock_movements_stock_lot_id_fkey"
end
