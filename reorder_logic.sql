-- =====================================================================
-- Inventory Management System : reorder recommendation
--
-- Logic
--   1. Take each office/item's average monthly consumption over the
--      last 3 months in the data (a 3-month moving average).
--   2. Add a 10% safety buffer  ->  target stock for next month.
--   3. Compare with stock on hand and order ONLY the shortfall.
--
--   reorder_qty = GREATEST(0, CEIL(avg_3m * 1.10) - stock_on_hand)
--
-- Assumes the latest month in the data is complete.
-- Requires views.sql (v_monthly_consumption, v_stock_on_hand).
-- =====================================================================
USE inventory_demo;

CREATE OR REPLACE VIEW v_reorder_recommendation AS
WITH month_grid AS (                       -- every month in the data period
    SELECT DISTINCT month_start FROM v_monthly_consumption
),
pairs AS (                                 -- every office/item combination
    SELECT office_id, item_id FROM opening_stock
),
filled AS (                                -- fill months with no usage as 0
    SELECT
        p.office_id,
        p.item_id,
        g.month_start,
        COALESCE(mc.qty_used, 0) AS qty_used
    FROM pairs AS p
    CROSS JOIN month_grid AS g
    LEFT JOIN v_monthly_consumption AS mc
           ON mc.office_id = p.office_id
          AND mc.item_id   = p.item_id
          AND mc.month_start = g.month_start
),
rolling AS (                               -- 3-month moving average via window function
    SELECT
        office_id,
        item_id,
        month_start,
        AVG(qty_used) OVER (
            PARTITION BY office_id, item_id
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS avg_3m,
        ROW_NUMBER() OVER (
            PARTITION BY office_id, item_id
            ORDER BY month_start DESC
        ) AS rn
    FROM filled
)
SELECT
    s.office_name,
    s.category_name,
    s.item_name,
    s.stock_on_hand,
    ROUND(r.avg_3m, 1)                                   AS avg_monthly_use_3m,
    CEIL(r.avg_3m * 1.10)                                AS target_stock,
    GREATEST(0, CEIL(r.avg_3m * 1.10) - s.stock_on_hand) AS reorder_qty,
    ROUND(s.stock_on_hand / NULLIF(r.avg_3m, 0), 1)      AS months_of_cover,
    CASE
        WHEN s.stock_on_hand < r.avg_3m       THEN 'CRITICAL'   -- under 1 month of cover
        WHEN s.stock_on_hand < r.avg_3m * 2   THEN 'LOW'        -- under 2 months
        ELSE 'OK'
    END AS stock_status
FROM rolling AS r
JOIN v_stock_on_hand AS s
  ON s.office_id = r.office_id AND s.item_id = r.item_id
WHERE r.rn = 1;                            -- latest month only

-- Example: what to order now, most urgent first
SELECT office_name, item_name, stock_on_hand, avg_monthly_use_3m,
       target_stock, reorder_qty, months_of_cover, stock_status
FROM v_reorder_recommendation
WHERE reorder_qty > 0
ORDER BY months_of_cover, office_name, item_name
LIMIT 20;
