DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'reservation_result'
  ) THEN
    CREATE TYPE reservation_result AS (
      request_id BIGINT,
      status VARCHAR,
      quantity_reserved NUMERIC,
      quantity_pending NUMERIC,
      lots_used INTEGER
    );
  END IF;
END
$$;

-- Reserva material para una solicitud respetando FIFO.
-- La función es deliberadamente la frontera transaccional: la lectura del
-- inventario, sus descuentos, los movimientos y el cambio de estado ocurren
-- en la misma transacción de la aplicación.
CREATE OR REPLACE FUNCTION reserve_material(
  p_request_id BIGINT,
  p_warehouse_id BIGINT,
  p_allow_partial BOOLEAN DEFAULT TRUE
) RETURNS reservation_result
LANGUAGE plpgsql
AS $$
DECLARE
  v_request reservation_requests%ROWTYPE;
  v_lot stock_lots%ROWTYPE;
  v_reserved NUMERIC(14,4);
  v_needed NUMERIC(14,4);
  v_available NUMERIC(14,4) := 0;
  v_moved NUMERIC(14,4);
  v_pending NUMERIC(14,4);
  v_status VARCHAR(16);
  v_lots_used INTEGER;
  v_movement_sum NUMERIC(14,4);
BEGIN
  -- P000x permite que el caller distinga errores de negocio de errores SQL
  -- inesperados sin depender del texto libre de la excepción.
  IF p_request_id IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'reserve_material: request_id_required';
  END IF;

  IF p_warehouse_id IS NULL OR p_warehouse_id <= 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0002',
      MESSAGE = 'reserve_material: warehouse_id_invalid',
      DETAIL = 'The supplied schema has no warehouses table; only positive identifiers can be accepted.';
  END IF;

  IF p_allow_partial IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0003',
      MESSAGE = 'reserve_material: allow_partial_required';
  END IF;

  SELECT *
    INTO v_request
    FROM reservation_requests
   WHERE id = p_request_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0004',
      MESSAGE = 'reserve_material: request_not_found',
      DETAIL = format('request_id=%s', p_request_id);
  END IF;

  IF v_request.status IN ('fulfilled', 'partial') THEN
    -- La fila de la solicitud está bloqueada. Por eso dos reintentos pueden
    -- entrar aquí de forma serializada y el segundo devuelve el resultado
    -- existente sin insertar movimientos duplicados.
    SELECT
      COALESCE(SUM(quantity_moved), 0),
      COUNT(*)::INTEGER
      INTO v_movement_sum, v_lots_used
      FROM stock_movements
     WHERE request_id = v_request.id;

    IF v_request.quantity_reserved <> v_movement_sum THEN
      RAISE EXCEPTION USING
        ERRCODE = 'P0005',
        MESSAGE = 'reserve_material: reservation_invariant_failed',
        DETAIL = format('request_id=%s', v_request.id);
    END IF;

    RETURN (
      v_request.id,
      v_request.status,
      v_request.quantity_reserved,
      v_request.quantity_required - v_request.quantity_reserved,
      v_lots_used
    )::reservation_result;
  END IF;

  IF v_request.status NOT IN ('pending', 'backordered') THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0006',
      MESSAGE = 'reserve_material: request_status_invalid',
      DETAIL = format('request_id=%s status=%s', v_request.id, v_request.status);
  END IF;

  IF v_request.quantity_required <= 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0007',
      MESSAGE = 'reserve_material: quantity_required_invalid',
      DETAIL = format('request_id=%s', v_request.id);
  END IF;

  PERFORM 1 FROM materials WHERE id = v_request.material_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0008',
      MESSAGE = 'reserve_material: material_not_found',
      DETAIL = format('material_id=%s', v_request.material_id);
  END IF;

  SELECT COALESCE(SUM(quantity_moved), 0)
    INTO v_movement_sum
    FROM stock_movements
   WHERE request_id = v_request.id;

  IF v_request.quantity_reserved <> v_movement_sum THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0005',
      MESSAGE = 'reserve_material: reservation_invariant_failed',
      DETAIL = format('request_id=%s', v_request.id);
  END IF;

  v_reserved := v_request.quantity_reserved;
  v_needed := v_request.quantity_required - v_reserved;

  -- Primero bloqueamos todos los lotes candidatos y calculamos si alcanza.
  -- El orden recibido + id hace FIFO determinista y el mismo orden de locks
  -- reduce el riesgo de deadlocks entre reservas concurrentes.
  FOR v_lot IN
    SELECT *
      FROM stock_lots
     WHERE material_id = v_request.material_id
       AND warehouse_id = p_warehouse_id
     ORDER BY received_at ASC, id ASC
     FOR UPDATE
  LOOP
    v_available := v_available + v_lot.quantity;
  END LOOP;

  IF v_available < v_needed AND NOT p_allow_partial THEN
    -- Una reserva no parcial es atómica desde el punto de vista del negocio:
    -- si no alcanza, cambia a backordered pero no consume ningún lote.
    UPDATE reservation_requests
       SET status = 'backordered', updated_at = now()
     WHERE id = v_request.id;

    RETURN (
      v_request.id,
      'backordered',
      v_reserved,
      v_request.quantity_required - v_reserved,
      0
    )::reservation_result;
  END IF;

  -- En esta segunda pasada consumimos en el mismo orden ya bloqueado. Una fila
  -- con cantidad cero se ignora y nunca genera un movimiento cero.
  FOR v_lot IN
    SELECT *
      FROM stock_lots
     WHERE material_id = v_request.material_id
       AND warehouse_id = p_warehouse_id
     ORDER BY received_at ASC, id ASC
     FOR UPDATE
  LOOP
    EXIT WHEN v_needed <= 0;
    CONTINUE WHEN v_lot.quantity <= 0;

    v_moved := LEAST(v_lot.quantity, v_needed);
    IF v_moved <= 0 THEN
      CONTINUE;
    END IF;

    UPDATE stock_lots
       SET quantity = quantity - v_moved
     WHERE id = v_lot.id
       AND quantity >= v_moved;

    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'P0009',
        MESSAGE = 'reserve_material: lot_update_failed',
        DETAIL = format('stock_lot_id=%s', v_lot.id);
    END IF;

    INSERT INTO stock_movements (request_id, stock_lot_id, quantity_moved)
    VALUES (v_request.id, v_lot.id, v_moved);

    v_reserved := v_reserved + v_moved;
    v_needed := v_needed - v_moved;
  END LOOP;

  v_pending := v_request.quantity_required - v_reserved;
  v_status := CASE WHEN v_pending = 0 THEN 'fulfilled' ELSE 'partial' END;

  UPDATE reservation_requests
     SET quantity_reserved = v_reserved,
         status = v_status,
         updated_at = now()
   WHERE id = v_request.id;

  SELECT COUNT(*)::INTEGER
    INTO v_lots_used
    FROM stock_movements
   WHERE request_id = v_request.id;

  -- Si algo falla antes de este punto, PostgreSQL revierte descuentos,
  -- movimientos y cambios de estado como una sola unidad.
  RETURN (
    v_request.id,
    v_status,
    v_reserved,
    v_pending,
    v_lots_used
  )::reservation_result;
END;
$$;
