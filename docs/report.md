# Munch: Campus Canteen Ordering & Inventory System
## DBMS Lab Project Report (Course Code: 24B15CS213)

## 1. System Overview & Architecture

Munch is a campus canteen ordering and automated inventory management database system engineered for JIIT Noida. Designed with a **database-centric architecture**, business logic, consistency rules, inventory balance adjustments, audit trails, and transactional state machines reside directly inside **PostgreSQL 15+** utilizing **PL/pgSQL triggers, stored procedures, and relational constraints**.

The Python backend (FastAPI + `psycopg` v3) operates as an ultra-thin communication gateway, delegating computation to the database engine. The frontend is a responsive web application providing student self-service ordering, live kitchen preparation tracking with automated polling, and an administrative operations control room.

```
+-----------------------------------------------------------------------------------+
|                                 Munch Client                                      |
|  - Menu & Outlet Selector    - Live Order Tracker & Polling                       |
|  - Cart & Multi-Payment Checkout - Admin Operations, Restock Suggestions & Analytics |
+-----------------------------------------------------------------------------------+
                                       |
                                       v  HTTP / REST (JSON)
+-----------------------------------------------------------------------------------+
|                        FastAPI Thin Gateway (Python 3.14)                         |
|  - Connection Pool (psycopg v3)                                                   |
|  - Direct Procedure Calls (CALL place_order, CALL process_payment)                |
|  - Zero ORM Overhead                                                              |
+-----------------------------------------------------------------------------------+
                                       |
                                       v  Native PostgreSQL Wire Protocol
+-----------------------------------------------------------------------------------+
|                           PostgreSQL 15+ Core Engine                              |
|  - 15 Relational Tables & Domain Types (order_status, payment_status, etc.)       |
|  - Triggers: T1 (Price Snapshot), T2 (Total Recalc),                              |
|              T3 (Stock Deduct on Order), T3b (Stock Restore on Cancel),           |
|              T4 (Restock Alert), T5 (Purchase Increment),                         |
|              T6 (Audit Log), T7 (State Validation)                                |
|  - Cursor Function: generate_restock_suggestions()                                |
|  - Views: v_order_details, v_low_stock, v_item_ratings, mv_daily_sales            |
|  - Indexes: B-Tree, Composite, and Partial                                        |
+-----------------------------------------------------------------------------------+
```

---

## 2. Relational Schema & Normalization Analysis

The schema comprises 15 relational tables:
1. `student`
2. `canteen`
3. `category`
4. `supplier`
5. `menu_item`
6. `inventory_item`
7. `staff`
8. `recipe`
9. `orders`
10. `order_item`
11. `payment`
12. `purchase`
13. `review`
14. `restock_alert`
15. `order_audit_log`

### 2.1 First Normal Form (1NF)
A relation is in 1NF if and only if all underlying domains contain atomic (indivisible) values, and there are no repeating groups or multi-valued attributes.
- **Atomicity:** All columns (`price`, `rating`, `quantity`, `order_date`) store scalar atomic values.
- **Unique Records:** Every table defines an explicit Primary Key (`student_id`, `canteen_id`, `order_id`, etc.) or composite Primary Key (`order_item(order_id, line_no)`, `recipe(item_id, inventory_id)`).
- **No Arrays/Repeating Groups:** Ordered line items are not stored as delimited strings or lists within the `orders` relation; rather, they are decomposed into the dedicated weak entity table `order_item`.

### 2.2 Second Normal Form (2NF)
A relation is in 2NF if it is in 1NF and every non-prime attribute is **fully functionally dependent** on the primary key (no partial functional dependency).
- In relations with single-column primary keys (`student`, `canteen`, `menu_item`, `orders`, `supplier`), partial dependency is impossible.
- In composite key relations:
  - `recipe(item_id, inventory_id)`: The non-prime attribute `qty_used` depends on both the menu item and the specific ingredient. A potato quantity cannot be determined from `item_id` alone. Hence, `qty_used` is fully functionally dependent on `{item_id, inventory_id}`.
  - `order_item(order_id, line_no)`: Attributes `item_id`, `quantity`, and `price_at_order` are dependent on the specific line entry of that order. Neither `order_id` alone nor `line_no` alone determines the ordered item. Thus, 2NF holds.

### 2.3 Third Normal Form (3NF) & BCNF
A relation is in 3NF if it is in 2NF and no non-prime attribute is transitively dependent on the primary key ($X \to Y$ and $Y \to Z$ where $Z$ is non-prime).
- Category names are isolated into the `category` relation; `menu_item` stores only `category_id` (FK), eliminating transitive dependencies (`item_id -> category_id -> category_name`).
- Canteen operational details reside in `canteen`; `staff` and `orders` reference `canteen_id` without duplicating address, contact, or operational hours.
- Student personal details reside in `student`; `orders` only references `student_id`.
- **Boyce-Codd Normal Form (BCNF):** A relation is in BCNF if for every non-trivial functional dependency $X \to Y$, $X$ is a superkey. In every table, all functional determinants are candidate keys (for example, in `student`, both `student_id` and `email` are candidate keys).

---

## 3. Derived Attributes, Historical Data & Consistency Maintenance

In relational database engineering, practical operational requirements require storing certain point-in-time data and maintaining derived attributes to avoid repeated expensive aggregations on hot read paths. Munch handles each case explicitly:

### 3.1 Point-in-Time Catalog Data: `order_item.price_at_order`
- **Distinction of Facts:** `menu_item.price` and `order_item.price_at_order` look similar, but they represent two fundamentally distinct facts:
  - `menu_item.price` is the *current catalog price* (mutable).
  - `order_item.price_at_order` is the *historical transaction price* at the moment of order placement (immutable).
- **Why Both Are Necessary:** If `order_item` joined dynamically to `menu_item.price`, a price update next semester (e.g., Chai increasing from ₹15 to ₹20) would rewrite past receipts and corrupt historical sales totals. Storing both attributes is correct relational design.
- **Consistency Enforcement:** Trigger `t1_order_item_before_insert` runs `BEFORE INSERT` on `order_item`, reading the active price from `menu_item` and locking it into `price_at_order`.

### 3.2 Derived Line Item Amount: `order_item.subtotal`
- **Definition:** The line total is derived from `quantity * price_at_order`.
- **Consistency Enforcement:** Implemented natively in PostgreSQL as a generated stored column:
  ```sql
  subtotal NUMERIC(10,2) GENERATED ALWAYS AS (quantity * price_at_order) STORED
  ```
  The database engine computes and updates it automatically whenever rows are written.

### 3.3 Maintained Header Aggregate: `orders.total_amount`
- **Definition:** The sum of all line item subtotals for an order ($\sum \text{subtotal}$).
- **Operational Justification:** Avoids re-aggregating the line items on every order status check, live tracking poll, or history lookup.
- **Consistency Enforcement:** Trigger `t2_order_item_recalc_total` runs `AFTER INSERT OR UPDATE OR DELETE` on `order_item`, recalculating and updating `orders.total_amount` within the same transaction.

### 3.4 Payment Record Total: `payment.amount`
- **Definition:** Records the exact amount charged at payment confirmation.
- **Consistency Enforcement:** Kept consistent by the `process_payment` stored procedure, which verifies that the submitted payment matches `orders.total_amount` before transitioning `payment_status` to `'SUCCESS'`.

### 3.5 Materialized Sales Analytics: `mv_daily_sales`
- **Definition:** Precomputed daily order counts and revenue aggregations per canteen.
- **Operational Justification:** Serves administrative dashboard queries without repeated scans across historical orders.
- **Consistency Enforcement:** Refreshed on demand or via scheduled job using `REFRESH MATERIALIZED VIEW CONCURRENTLY` enabled by the unique index `idx_uq_mv_daily_sales(sales_date, canteen_id)`.

---

## 4. Trigger Inventory & Transactional State Management

The database utilizes 8 PL/pgSQL triggers to maintain data integrity, enforce state machines, and automate inventory adjustments:

| Trigger | Target Table | Event | Responsibility |
|---|---|---|---|
| **T1: `t1_order_item_before_insert`** | `order_item` | `BEFORE INSERT` | Fetches active item price from `menu_item` and locks it into `price_at_order`. |
| **T2: `t2_order_item_recalc_total`** | `order_item` | `AFTER INSERT / UPDATE / DELETE` | Recalculates `orders.total_amount` to maintain header consistency. |
| **T3: `t3_order_item_deduct_stock`** | `order_item` | `AFTER INSERT` | Deducts required ingredients from `inventory_item` using `recipe` definitions with `FOR UPDATE` locking. |
| **T3b: `t3b_order_cancel_restore_stock`** | `orders` | `AFTER UPDATE OF order_status` | Restores deducted ingredients back to `inventory_item` when an order is cancelled. |
| **T4: `t4_inventory_low_stock_alert`** | `inventory_item` | `AFTER INSERT / UPDATE OF quantity_available` | Automatically raises an unresolved record in `restock_alert` when stock falls below `reorder_level`. |
| **T5: `t5_purchase_increase_stock`** | `purchase` | `AFTER INSERT` | Increments inventory quantities when receiving raw materials from suppliers. |
| **T6: `t6_order_status_audit`** | `orders` | `AFTER INSERT / UPDATE OF order_status` | Appends historical state transitions to `order_audit_log` with timestamp. |
| **T7: `t7_order_status_validate`** | `orders` | `BEFORE UPDATE OF order_status` | Enforces the allowed order state machine (`PLACED` &rarr; `CONFIRMED` &rarr; `PREPARING` &rarr; `READY` &rarr; `COMPLETED` or `CANCELLED`). |

> [!IMPORTANT]
> **Stock Deduction Timing:** Stock is deducted **when the order is placed** (upon line item insertion), not when it is confirmed. Deducting stock immediately at order creation prevents race conditions where two students might concurrently claim the last available portion of an item. If the order is subsequently cancelled before preparation, trigger **T3b** restores the stock back to the inventory balance.

---

## 5. Relational Views & Materialized Analytics

Located in `db/05_views_indexes.sql`:

| View Name | Type | Purpose & DBMS Significance |
|---|---|---|
| `v_order_details` | Relational View | 6-table INNER/LEFT JOIN consolidating order, student, canteen, line item, and payment status for simplified reporting and API consumption. |
| `v_low_stock` | Filtered Operational View | Calculates inventory shortfalls (`reorder_level - quantity_available`), urgency tiers (`CRITICAL_DEPLETED`, `HIGH_ALERT`), and joins unresolved alerts. |
| `v_item_ratings` | Aggregate View | Aggregates reviews with `ROUND(AVG(rating), 2)` and total review count, preserving unreviewed items via `LEFT JOIN`. |
| `mv_daily_sales` | **Materialized View** | Precomputed OLAP sales rollup grouped by date and canteen. Includes unique index `idx_uq_mv_daily_sales` enabling zero-downtime `REFRESH MATERIALIZED VIEW CONCURRENTLY`. |

---

## 6. Indexing Strategy & EXPLAIN ANALYZE Performance

### 6.1 Index Catalog
1. **`idx_orders_student_id`** (B-Tree on `orders(student_id)`): Optimizes student order history queries.
2. **`idx_orders_order_date`** (B-Tree on `orders(order_date)`): Speeds up financial date-range filters.
3. **`idx_order_item_item_id`** (B-Tree on `order_item(item_id)`): Accelerates menu item sales ranking rollups.
4. **`idx_orders_canteen_status_date`** (Composite B-Tree on `orders(canteen_id, order_status, order_date)`): Targets live kitchen queues filtering by outlet and status.
5. **`idx_menu_item_active`** (Partial B-Tree on `menu_item(canteen_id, category_id)` WHERE `availability_status = TRUE`): Reduces index footprint by indexing only currently available catalog items.
6. **`idx_orders_active_queue`** (Partial B-Tree on `orders(canteen_id, order_time)` WHERE `order_status IN ('PLACED', 'CONFIRMED', 'PREPARING', 'READY')`): Indexes active orders, keeping historical archive orders out of the active index cache.
7. **`idx_review_item_id`** (B-Tree on `review(item_id)`): Speeds up review lookups per dish.
8. **`idx_uq_mv_daily_sales`** (Unique B-Tree on `mv_daily_sales(sales_date, canteen_id)`): Enables concurrent refresh of daily sales materialized views.

### 6.2 EXPLAIN (ANALYZE, BUFFERS) Performance Analysis

In relational databases, PostgreSQL's cost-based query planner chooses execution plans based on table statistics and page count:

- **Small Table Behavior:** When a table contains few rows (such as the initial seed dataset), the entire table occupies only 1 or 2 8KB shared buffer pages (`Buffers: shared hit=2`, execution time ~0.05 ms). The planner prefers a sequential scan because traversing an index B-Tree plus fetching heap pages introduces unnecessary page read overhead.
- **Indexed Volume Behavior:** When table volume grows, selective queries (e.g., retrieving orders for a specific student among thousands of records) benefit substantially from B-Tree indexing.

To verify this on PostgreSQL 17, we evaluated a student lookup query (`SELECT order_id, order_date, total_amount FROM orders WHERE student_id = 42;`) against a 10,000-order dataset with 0.1% selectivity (10 matching rows):

#### With Index (`idx_orders_student_id`):
```
Bitmap Heap Scan on orders (cost=1.46..12.31 rows=10 width=12) (actual time=0.049..0.061 rows=10 loops=1)
  Recheck Cond: (student_id = 42)
  Heap Blocks: exact=10
  Buffers: local hit=10 read=2
  ->  Bitmap Index Scan on idx_orders_student_id (cost=0.00..1.46 rows=10 width=0) (actual time=0.035..0.036 rows=10 loops=1)
        Index Cond: (student_id = 42)
        Buffers: local read=2
Planning Time: 0.195 ms
Execution Time: 0.092 ms
```

#### Without Index (Sequential Scan Forced):
```
Seq Scan on orders (cost=0.00..253.00 rows=10 width=12) (actual time=0.018..0.831 rows=10 loops=1)
  Filter: (student_id = 42)
  Rows Removed by Filter: 9990
  Buffers: local hit=128
Planning Time: 0.063 ms
Execution Time: 0.855 ms
```

- **I/O Comparison:** The indexed query reads only 12 buffer blocks (10 heap pages + 2 index pages) to retrieve the target rows. The sequential scan reads all 128 table pages and filters 9,990 non-matching rows, reducing execution time from **0.855 ms** to **0.092 ms**.

---

## 7. Analytical SQL Catalog (`db/06_queries.sql`)

The project implements 17 distinct analytical queries addressing core business operations:

1. **Multi-table INNER JOIN:** Complete itemized receipt generator joining student, canteen, menu item, and order item.
2. **LEFT OUTER JOIN:** Menu sentiment analysis preserving items with zero reviews.
3. **RIGHT OUTER JOIN:** Vendor performance audit tracking inactive suppliers who have never fulfilled purchases.
4. **FULL OUTER JOIN:** Ingredient reconciliation cross-matching recipes against raw inventory to detect orphaned stock.
5. **Scalar Subquery:** Price anomaly detection identifying dishes priced higher than their category average.
6. **Correlated Subquery:** Student spend outlier analysis finding patrons whose spend exceeds the campus-wide student average.
7. **GROUP BY & HAVING (Financial Threshold):** High-yield canteen ranking with revenue exceeding ₹300.
8. **GROUP BY & HAVING (Volume Threshold):** High-velocity dish identification ordered more than once.
9. **Common Table Expression (CTE):** Multi-level department dining spend distribution and percentage contribution.
10. **Recursive CTE (`WITH RECURSIVE`):** Continuous 7-day calendar series generation joined with orders to display days with zero sales explicitly.
11. **Window Function (`RANK` & `DENSE_RANK`):** Partitions menu items by category to crown top-selling dishes.
12. **Window Function (Running Total):** Cumulative day-by-day revenue progression partitioned by canteen.
13. **Window Function (`LAG`):** Day-over-day sales velocity and percentage growth comparison.
14. **`EXISTS` & `NOT EXISTS`:** Identification of inactive registered students and outlets with unresolved low-stock alerts.
15. **Set Operations (`UNION`, `INTERSECT`, `EXCEPT`):** Student preference segmentation identifying patrons who ordered both Snacks and Beverages, vs Snacks exclusively at JIIT Annapurna.
16. **Conditional Logic (`CASE` & `COALESCE`):** Dynamic loyalty tier segmentation (Platinum, Gold, Silver, Bronze).
17. **Temporal Extraction:** Hourly order clustering using `EXTRACT(HOUR FROM order_time)` identifying peak campus rush hours.

---

## 8. Frontend User Interface

The frontend (`frontend/`) delivers an interactive single-page application built with modern web standards:
- **Menu & Filtering:** Dynamic canteen switching, category pill filters, search query filtering, veg indicators, star ratings, and real-time inventory availability badges.
- **Cart & Multi-Payment Checkout:** Quantity adjustments, cross-canteen guardrails, itemized bills, and payment method selection (UPI, Card, Digital Wallet, Cash).
- **Live Order Tracker:** Visual stage-by-stage stepper (`PLACED` &rarr; `CONFIRMED` &rarr; `PREPARING` &rarr; `READY` &rarr; `COMPLETED`) with automated 3.5s polling and instant order cancellation triggering inventory restoration.
- **Order History:** Student-specific historical receipts with itemized subtotal inspection and direct shortcuts to rate menu items.
- **Review System:** Interactive 5-star rating widget, text feedback submission, and campus-wide review feed.
- **Admin Control Room:** Kitchen dispatch management, real-time low-stock alerts, cursor-driven restock recommendations, supplier purchase modal, window-function top item leaderboards, and order audit trail timeline inspector.
- **Clean REST Architecture:** Connects directly to the FastAPI backend (`http://localhost:8000`) with live polling and zero mock overhead.
