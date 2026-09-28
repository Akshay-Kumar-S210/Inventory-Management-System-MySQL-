-- =====================================================================
-- Inventory Management System : analysis queries
-- Run after schema.sql, sample_data.sql, views.sql, reorder_logic.sql.
-- Each query is independent; run them one at a time.
-- =====================================================================
USE inventory_demo;

-- ---------------------------------------------------------------------
-- Q1. Monthly consumption by category (pivot with CASE WHEN)
-- ---------------------------------------------------------------------
SELECT
    category_name,
    SUM(CASE WHEN month_start = '2026-01-01' THEN qty_used ELSE 0 END) AS jan,
    SUM(CASE WHEN month_start = '2026-02-01' THEN qty_used ELSE 0 END) AS feb,
    SUM(CASE WHEN month_start = '2026-03-01' THEN qty_used ELSE 0 END) AS mar,
    SUM(CASE WHEN month_start = '2026-04-01' THEN qty_used ELSE 0 END) AS apr,
    SUM(CASE WHEN month_start = '2026-05-01' THEN qty_used ELSE 0 END) AS may,
    SUM(CASE WHEN month_start = '2026-06-01' THEN qty_used ELSE 0 END) AS jun,
    SUM(qty_used) AS total
FROM v_monthly_consumption
GROUP BY category_name
ORDER BY total DESC;

-- ---------------------------------------------------------------------
-- Q2. Top 3 most-consumed items in each office (ROW_NUMBER, top-N per group)
-- ---------------------------------------------------------------------
WITH item_totals AS (
    SELECT office_name, item_name, SUM(qty_used) AS total_used
    FROM v_monthly_consumption
    GROUP BY office_name, item_name
),
ranked AS (
    SELECT office_name, item_name, total_used,
           ROW_NUMBER() OVER (PARTITION BY office_name ORDER BY total_used DESC) AS rn
    FROM item_totals
)
SELECT office_name, rn AS item_rank, item_name, total_used
FROM ranked
WHERE rn <= 3
ORDER BY office_name, rn;

-- ---------------------------------------------------------------------
-- Q3. Vendor spend and share of total spend (SUM OVER for the grand total)
-- ---------------------------------------------------------------------
SELECT
    v.vendor_name,
    COUNT(*)                              AS purchase_lines,
    ROUND(SUM(p.quantity * p.unit_price), 2) AS spend,
    ROUND(100 * SUM(p.quantity * p.unit_price)
              / SUM(SUM(p.quantity * p.unit_price)) OVER (), 1) AS pct_of_total
FROM purchases AS p
JOIN vendors   AS v ON v.vendor_id = p.vendor_id
GROUP BY v.vendor_id, v.vendor_name
ORDER BY spend DESC;

-- ---------------------------------------------------------------------
-- Q4. Month-over-month purchase spend with change % (LAG)
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT month_start, SUM(purchase_amount) AS spend
    FROM v_monthly_purchases
    GROUP BY month_start
)
SELECT
    month_start,
    ROUND(spend, 2)                                   AS spend,
    ROUND(LAG(spend) OVER (ORDER BY month_start), 2)  AS prev_month_spend,
    ROUND(100 * (spend - LAG(spend) OVER (ORDER BY month_start))
              / LAG(spend) OVER (ORDER BY month_start), 1) AS change_pct
FROM monthly
ORDER BY month_start;

-- ---------------------------------------------------------------------
-- Q5. Running total of purchase spend per city (window with PARTITION BY)
-- ---------------------------------------------------------------------
WITH city_month AS (
    SELECT c.city_name, mp.month_start, SUM(mp.purchase_amount) AS spend
    FROM v_monthly_purchases AS mp
    JOIN offices AS o ON o.office_id = mp.office_id
    JOIN cities  AS c ON c.city_id   = o.city_id
    GROUP BY c.city_name, mp.month_start
)
SELECT
    city_name,
    month_start,
    ROUND(spend, 2) AS spend,
    ROUND(SUM(spend) OVER (PARTITION BY city_name ORDER BY month_start), 2) AS running_spend
FROM city_month
ORDER BY city_name, month_start;

-- ---------------------------------------------------------------------
-- Q6. Inter-office stock transfers: who sends what to whom (two joins to offices)
-- ---------------------------------------------------------------------
SELECT
    fo.office_name AS from_office,
    too.office_name AS to_office,
    COUNT(*)            AS transfers,
    SUM(t.quantity)     AS units_moved
FROM stock_transfers AS t
JOIN offices AS fo  ON fo.office_id  = t.from_office_id
JOIN offices AS too ON too.office_id = t.to_office_id
GROUP BY fo.office_name, too.office_name
ORDER BY units_moved DESC;

-- ---------------------------------------------------------------------
-- Q7. Unit price change per item: first vs latest purchase (FIRST_VALUE / LAST_VALUE)
-- ---------------------------------------------------------------------
SELECT DISTINCT
    i.item_name,
    FIRST_VALUE(p.unit_price) OVER w AS first_price,
    LAST_VALUE(p.unit_price)  OVER w AS latest_price,
    ROUND(100 * (LAST_VALUE(p.unit_price) OVER w - FIRST_VALUE(p.unit_price) OVER w)
              / FIRST_VALUE(p.unit_price) OVER w, 1) AS price_change_pct
FROM purchases AS p
JOIN items     AS i ON i.item_id = p.item_id
WINDOW w AS (PARTITION BY p.item_id
             ORDER BY p.purchase_date, p.purchase_id
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
ORDER BY price_change_pct DESC;

-- ---------------------------------------------------------------------
-- Q8. Office/item combinations with less than 1 month of cover (uses the reorder view)
-- ---------------------------------------------------------------------
SELECT office_name, category_name, item_name, stock_on_hand, avg_monthly_use_3m, reorder_qty
FROM v_reorder_recommendation
WHERE stock_status = 'CRITICAL'
ORDER BY category_name, office_name, item_name;

-- ---------------------------------------------------------------------
-- Q9. Estimated cost of the recommended reorder, by category
-- ---------------------------------------------------------------------
SELECT
    r.category_name,
    SUM(r.reorder_qty)                       AS units_to_order,
    ROUND(SUM(r.reorder_qty * i.unit_price), 2) AS estimated_cost
FROM v_reorder_recommendation AS r
JOIN items AS i ON i.item_name = r.item_name
WHERE r.reorder_qty > 0
GROUP BY r.category_name
ORDER BY estimated_cost DESC;

-- ---------------------------------------------------------------------
-- Q10. Data-quality check: any office/item with negative stock? (should return 0 rows)
-- ---------------------------------------------------------------------
SELECT * FROM v_stock_on_hand WHERE stock_on_hand < 0;

-- ---------------------------------------------------------------------
-- Q11. Check index usage on a date-range filter
-- ---------------------------------------------------------------------
EXPLAIN
SELECT office_id, SUM(quantity_used)
FROM consumption
WHERE consumption_date >= '2026-06-01' AND consumption_date < '2026-07-01'
GROUP BY office_id;
