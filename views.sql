-- =====================================================================
-- Inventory Management System : reporting views
-- Run after schema.sql and sample_data.sql.
-- CREATE OR REPLACE VIEW keeps re-runs safe (no dropping needed).
-- =====================================================================
USE inventory_demo;

-- ---------------------------------------------------------------------
-- 1. Monthly consumption per office and item
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_monthly_consumption AS
SELECT
    DATE_FORMAT(c.consumption_date, '%Y-%m-01') AS month_start,
    c.office_id,
    o.office_name,
    c.item_id,
    i.item_name,
    cat.category_name,
    SUM(c.quantity_used) AS qty_used
FROM consumption AS c
JOIN offices    AS o   ON o.office_id = c.office_id
JOIN items      AS i   ON i.item_id   = c.item_id
JOIN categories AS cat ON cat.category_id = i.category_id
GROUP BY month_start, c.office_id, o.office_name, c.item_id, i.item_name, cat.category_name;

-- ---------------------------------------------------------------------
-- 2. Monthly purchases per office and item (quantity and spend)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_monthly_purchases AS
SELECT
    DATE_FORMAT(p.purchase_date, '%Y-%m-01') AS month_start,
    p.office_id,
    o.office_name,
    p.item_id,
    i.item_name,
    cat.category_name,
    SUM(p.quantity)                AS qty_purchased,
    SUM(p.quantity * p.unit_price) AS purchase_amount
FROM purchases  AS p
JOIN offices    AS o   ON o.office_id = p.office_id
JOIN items      AS i   ON i.item_id   = p.item_id
JOIN categories AS cat ON cat.category_id = i.category_id
GROUP BY month_start, p.office_id, o.office_name, p.item_id, i.item_name, cat.category_name;

-- ---------------------------------------------------------------------
-- 3. Current stock on hand per office and item
--    stock = opening + purchases + transfers in - transfers out - consumption
--    Each source is aggregated first, then joined, to avoid row multiplication.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_stock_on_hand AS
SELECT
    os.office_id,
    o.office_name,
    os.item_id,
    i.item_name,
    cat.category_name,
    os.quantity
      + COALESCE(pur.qty, 0)
      + COALESCE(tin.qty, 0)
      - COALESCE(tout.qty, 0)
      - COALESCE(con.qty, 0) AS stock_on_hand
FROM opening_stock AS os
JOIN offices    AS o   ON o.office_id = os.office_id
JOIN items      AS i   ON i.item_id   = os.item_id
JOIN categories AS cat ON cat.category_id = i.category_id
LEFT JOIN (SELECT office_id, item_id, SUM(quantity) AS qty
           FROM purchases GROUP BY office_id, item_id) AS pur
       ON pur.office_id = os.office_id AND pur.item_id = os.item_id
LEFT JOIN (SELECT to_office_id AS office_id, item_id, SUM(quantity) AS qty
           FROM stock_transfers GROUP BY to_office_id, item_id) AS tin
       ON tin.office_id = os.office_id AND tin.item_id = os.item_id
LEFT JOIN (SELECT from_office_id AS office_id, item_id, SUM(quantity) AS qty
           FROM stock_transfers GROUP BY from_office_id, item_id) AS tout
       ON tout.office_id = os.office_id AND tout.item_id = os.item_id
LEFT JOIN (SELECT office_id, item_id, SUM(quantity_used) AS qty
           FROM consumption GROUP BY office_id, item_id) AS con
       ON con.office_id = os.office_id AND con.item_id = os.item_id;
