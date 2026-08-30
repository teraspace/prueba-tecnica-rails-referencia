TRUNCATE stock_movements, reservation_requests, stock_lots, materials RESTART IDENTITY CASCADE;

INSERT INTO materials (code, unit) VALUES
  ('ALU-6063', 'mm'),
  ('PVC-BLANCO', 'mm');

INSERT INTO stock_lots (material_id, warehouse_id, quantity, received_at)
SELECT id, 10, 10.0000, '2026-01-01 08:00:00+00' FROM materials WHERE code = 'ALU-6063'
UNION ALL
SELECT id, 10, 4.0000, '2026-01-02 08:00:00+00' FROM materials WHERE code = 'ALU-6063'
UNION ALL
SELECT id, 20, 100.0000, '2026-01-01 08:00:00+00' FROM materials WHERE code = 'ALU-6063';

INSERT INTO reservation_requests (production_order_id, material_id, quantity_required)
SELECT 1001, id, 8.0000 FROM materials WHERE code = 'ALU-6063';
