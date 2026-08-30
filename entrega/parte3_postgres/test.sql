\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  v_material_id BIGINT;
  v_request_id BIGINT;
  v_first_lot_id BIGINT;
  v_second_lot_id BIGINT;
  v_status VARCHAR;
  v_reserved NUMERIC;
  v_pending NUMERIC;
  v_lots_used INTEGER;
  v_movement_count INTEGER;
  v_movement_sum NUMERIC;
  v_quantity NUMERIC;
BEGIN
  -- 1. Cabe en un lote.
  TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;
  INSERT INTO materials (code, unit) VALUES ('TEST-ONE', 'u') RETURNING id INTO v_material_id;
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 10.0000, '2026-01-01 00:00:00+00')
  RETURNING id INTO v_first_lot_id;
  INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
  VALUES (1, v_material_id, 6.0000) RETURNING id INTO v_request_id;

  SELECT request_id, status, quantity_reserved, quantity_pending, lots_used
    INTO v_request_id, v_status, v_reserved, v_pending, v_lots_used
    FROM reserve_material(v_request_id, 10, TRUE);
  IF v_status <> 'fulfilled' OR v_reserved <> 6.0000 OR v_pending <> 0 OR v_lots_used <> 1 THEN
    RAISE EXCEPTION 'single-lot reservation failed';
  END IF;

  -- 2. Requiere varios lotes y respeta FIFO.
  TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;
  INSERT INTO materials (code, unit) VALUES ('TEST-MULTI', 'u') RETURNING id INTO v_material_id;
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 3.0000, '2026-01-01 00:00:00+00') RETURNING id INTO v_first_lot_id;
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 5.0000, '2026-01-02 00:00:00+00') RETURNING id INTO v_second_lot_id;
  INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
  VALUES (2, v_material_id, 7.0000) RETURNING id INTO v_request_id;

  SELECT status, quantity_reserved, quantity_pending, lots_used
    INTO v_status, v_reserved, v_pending, v_lots_used
    FROM reserve_material(v_request_id, 10, TRUE);
  SELECT COUNT(*)::INTEGER, COALESCE(SUM(quantity_moved), 0)
    INTO v_movement_count, v_movement_sum
    FROM stock_movements WHERE request_id = v_request_id;
  IF v_status <> 'fulfilled' OR v_reserved <> 7.0000 OR v_pending <> 0 OR v_lots_used <> 2
     OR v_movement_count <> 2 OR v_movement_sum <> 7.0000
     OR (SELECT stock_lot_id FROM stock_movements WHERE request_id = v_request_id ORDER BY id LIMIT 1) <> v_first_lot_id
     OR (SELECT quantity FROM stock_lots WHERE id = v_second_lot_id) <> 1.0000 THEN
    RAISE EXCEPTION 'multi-lot FIFO reservation failed';
  END IF;

  -- 3. Agota el inventario exactamente.
  TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;
  INSERT INTO materials (code, unit) VALUES ('TEST-EXACT', 'u') RETURNING id INTO v_material_id;
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 5.0000, '2026-01-01 00:00:00+00');
  INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
  VALUES (3, v_material_id, 5.0000) RETURNING id INTO v_request_id;
  SELECT status, quantity_reserved, quantity_pending INTO v_status, v_reserved, v_pending
    FROM reserve_material(v_request_id, 10, TRUE);
  IF v_status <> 'fulfilled' OR v_reserved <> 5.0000 OR v_pending <> 0
     OR (SELECT quantity FROM stock_lots LIMIT 1) <> 0.0000 THEN
    RAISE EXCEPTION 'exact exhaustion failed';
  END IF;

  -- 4. Excede inventario con allow_partial = true.
  TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;
  INSERT INTO materials (code, unit) VALUES ('TEST-PARTIAL', 'u') RETURNING id INTO v_material_id;
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 4.0000, '2026-01-01 00:00:00+00:00');
  INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
  VALUES (4, v_material_id, 6.0000) RETURNING id INTO v_request_id;
  SELECT status, quantity_reserved, quantity_pending INTO v_status, v_reserved, v_pending
    FROM reserve_material(v_request_id, 10, TRUE);
  IF v_status <> 'partial' OR v_reserved <> 4.0000 OR v_pending <> 2.0000 THEN
    RAISE EXCEPTION 'partial reservation failed';
  END IF;

  -- 5. Excede inventario con allow_partial = false: no consume.
  TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;
  INSERT INTO materials (code, unit) VALUES ('TEST-BACKORDER', 'u') RETURNING id INTO v_material_id;
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 4.0000, '2026-01-01 00:00:00+00:00');
  INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
  VALUES (5, v_material_id, 6.0000) RETURNING id INTO v_request_id;
  SELECT status, quantity_reserved, quantity_pending INTO v_status, v_reserved, v_pending
    FROM reserve_material(v_request_id, 10, FALSE);
  SELECT COUNT(*)::INTEGER INTO v_movement_count FROM stock_movements;
  SELECT quantity INTO v_quantity FROM stock_lots LIMIT 1;
  IF v_status <> 'backordered' OR v_reserved <> 0.0000 OR v_pending <> 6.0000
     OR v_movement_count <> 0 OR v_quantity <> 4.0000 THEN
    RAISE EXCEPTION 'backorder reservation failed';
  END IF;

  -- 6. Material sin lotes: partial explícito con cero reservado.
  TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;
  INSERT INTO materials (code, unit) VALUES ('TEST-EMPTY', 'u') RETURNING id INTO v_material_id;
  INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
  VALUES (6, v_material_id, 2.0000) RETURNING id INTO v_request_id;
  SELECT status, quantity_reserved, quantity_pending INTO v_status, v_reserved, v_pending
    FROM reserve_material(v_request_id, 10, TRUE);
  IF v_status <> 'partial' OR v_reserved <> 0.0000 OR v_pending <> 2.0000 THEN
    RAISE EXCEPTION 'empty inventory reservation failed';
  END IF;

  -- 7. Lote con cantidad cero no crea movimiento.
  TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;
  INSERT INTO materials (code, unit) VALUES ('TEST-ZERO', 'u') RETURNING id INTO v_material_id;
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 0.0000, '2026-01-01 00:00:00+00:00');
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 3.0000, '2026-01-02 00:00:00+00:00');
  INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
  VALUES (7, v_material_id, 3.0000) RETURNING id INTO v_request_id;
  SELECT status, quantity_reserved INTO v_status, v_reserved
    FROM reserve_material(v_request_id, 10, TRUE);
  SELECT COUNT(*)::INTEGER INTO v_movement_count FROM stock_movements WHERE request_id = v_request_id;
  IF v_status <> 'fulfilled' OR v_reserved <> 3.0000 OR v_movement_count <> 1
     OR EXISTS (SELECT 1 FROM stock_movements WHERE quantity_moved <= 0) THEN
    RAISE EXCEPTION 'zero-quantity lot handling failed';
  END IF;

  -- 8. Segunda llamada idempotente.
  TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;
  INSERT INTO materials (code, unit) VALUES ('TEST-IDEMPOTENT', 'u') RETURNING id INTO v_material_id;
  INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
  VALUES (v_material_id, 10, 10.0000, '2026-01-01 00:00:00+00');
  INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
  VALUES (8, v_material_id, 6.0000) RETURNING id INTO v_request_id;
  SELECT status, quantity_reserved INTO v_status, v_reserved
    FROM reserve_material(v_request_id, 10, TRUE);
  SELECT status, quantity_reserved INTO v_status, v_reserved
    FROM reserve_material(v_request_id, 10, TRUE);
  SELECT COUNT(*)::INTEGER, COALESCE(SUM(quantity_moved), 0)
    INTO v_movement_count, v_movement_sum
    FROM stock_movements WHERE request_id = v_request_id;
  IF v_status <> 'fulfilled' OR v_reserved <> 6.0000
     OR v_movement_count <> 1 OR v_movement_sum <> 6.0000 THEN
    RAISE EXCEPTION 'idempotent retry failed';
  END IF;

  RAISE NOTICE 'reserve_material tests passed';
END
$$;

COMMIT;
