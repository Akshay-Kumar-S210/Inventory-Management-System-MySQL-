# Inventory Management System (MySQL)

A MySQL project that models inventory across **2 cities and 4 offices**: purchases, daily consumption, inter-office stock transfers, and a **reorder recommendation** based on recent usage.

> **All data here is fictional.** City, office, vendor and item names, quantities and prices are invented sample data. Nothing comes from a real company.

## What it covers

Five item categories are tracked: Housekeeping, Stationery, New Joining Kits, BMS Materials and First Aid.

| Question | Where to look |
|---|---|
| How much does each office use per month? | `v_monthly_consumption` |
| What did we buy, from whom, at what cost? | `v_monthly_purchases`, Q3, Q4 |
| How much stock is on hand right now? | `v_stock_on_hand` |
| What should we order next? | `v_reorder_recommendation` |
| Which offices trade stock with each other? | Q6 |

## Files

| File | Purpose |
|---|---|
| `schema.sql` | Creates the `inventory_demo` database, tables, keys, indexes and check constraints |
| `sample_data.sql` | Loads fictional data for Jan to Jun 2026 |
| `views.sql` | Reporting views: monthly consumption, monthly purchases, stock on hand |
| `reorder_logic.sql` | The reorder recommendation view, built with CTEs and window functions |
| `queries.sql` | 11 analysis queries (pivoting, ranking, LAG, running totals, EXPLAIN) |

## Data model

```
cities ──< offices ──< opening_stock >── items >── categories
                 │                        │
                 ├──< purchases >─────────┤──< vendors (via purchases)
                 ├──< consumption >───────┤
                 └──< stock_transfers >───┘   (from_office_id, to_office_id)
```

| Table | Rows (sample) | Description |
|---|---|---|
| `cities` | 2 | Cities |
| `offices` | 4 | Offices, each in one city |
| `categories` | 5 | Item categories |
| `vendors` | 8 | Suppliers |
| `items` | 20 | Items with unit and standard price |
| `opening_stock` | 80 | Stock per office and item on 2026-01-01 |
| `purchases` | 451 | Purchase lines with vendor, quantity and price |
| `consumption` | 5,369 | Daily usage per office and item |
| `stock_transfers` | 57 | Stock moved between offices |

**Stock on hand** = opening stock + purchases + transfers in − transfers out − consumption.

## Reorder logic

1. Take each office and item's **average monthly consumption over the last 3 months** (a moving average using a window function).
2. Add a **10% safety buffer** to get the target stock.
3. Compare with stock on hand and order **only the shortfall**.

```
reorder_qty = GREATEST(0, CEIL(avg_3m * 1.10) - stock_on_hand)
```

Each row also gets a `stock_status`: `CRITICAL` (under 1 month of cover), `LOW` (under 2 months) or `OK`. The logic assumes the latest month in the data is complete.

## How to run

You need MySQL 8.x (written for MySQL Command Line Client 8.4).

```bash
mysql -u root -p < schema.sql
mysql -u root -p < sample_data.sql
mysql -u root -p < views.sql
mysql -u root -p < reorder_logic.sql
mysql -u root -p < queries.sql
```

Or from inside the MySQL client:

```sql
source schema.sql;
source sample_data.sql;
source views.sql;
source reorder_logic.sql;
```

Every script uses `CREATE OR REPLACE VIEW`, so the views can be re-run safely. `schema.sql` creates the tables, so run it only once on a fresh database.

## Sample output

> **Sandbox output.** These results come from running the scripts on the fictional sample data above, on a MySQL 8.0 test server. They are not real business data. Your numbers will match only if you load the same `sample_data.sql`.

**Q1: Monthly consumption by category**

| category_name | jan | feb | mar | apr | may | jun | total |
|---|---|---|---|---|---|---|---|
| Stationery | 896 | 791 | 814 | 917 | 899 | 893 | 5210 |
| Housekeeping | 575 | 535 | 606 | 646 | 646 | 640 | 3648 |
| New Joining Kits | 259 | 293 | 311 | 306 | 297 | 339 | 1805 |
| First Aid | 213 | 219 | 224 | 236 | 252 | 262 | 1406 |
| BMS Materials | 148 | 79 | 97 | 98 | 82 | 96 | 600 |

**Q4: Month-over-month purchase spend (LAG)**

| month_start | spend | prev_month_spend | change_pct |
|---|---|---|---|
| 2026-01-01 | 309164.57 | NULL | NULL |
| 2026-02-01 | 312133.14 | 309164.57 | 1.0 |
| 2026-03-01 | 345895.08 | 312133.14 | 10.8 |
| 2026-04-01 | 351192.03 | 345895.08 | 1.5 |
| 2026-05-01 | 355810.47 | 351192.03 | 1.3 |
| 2026-06-01 | 336086.41 | 355810.47 | -5.5 |

**Q9: Estimated cost of the recommended reorder, by category**

| category_name | units_to_order | estimated_cost |
|---|---|---|
| BMS Materials | 64 | 24010.00 |
| Stationery | 14 | 1960.00 |
| Housekeeping | 8 | 1840.00 |
| First Aid | 21 | 1416.00 |

## SQL concepts demonstrated

- Joins across multiple tables, including joining `offices` twice for transfers
- Aggregation with `GROUP BY` and pivoting with `CASE WHEN`
- CTEs, and views built on other views
- Window functions: `ROW_NUMBER`, `LAG`, `FIRST_VALUE`, `LAST_VALUE`, running `SUM() OVER`, moving `AVG() OVER`
- Top-N per group
- Subqueries in `FROM` to avoid row multiplication when joining several transaction tables
- Foreign keys, check constraints and indexes, plus `EXPLAIN` to confirm index use
- A data-quality check query (Q10), which should return 0 rows

## Common pitfalls

- **Run order matters.** The views depend on the tables, and `reorder_logic.sql` depends on `views.sql`.
- **Do not join purchases, consumption and transfers directly to each other.** Each has many rows per office and item, so the totals get multiplied. `v_stock_on_hand` aggregates each source first, then joins.
- **`LAST_VALUE` needs an explicit frame** (`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`). The default frame stops at the current row and returns the wrong result.
