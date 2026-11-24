\set QUIET on
\pset pager off
SET search_path TO munch, public;
\echo '=== 2. JOINs and aggregation: revenue per canteen and category ==='
\echo
SELECT c.name                       AS canteen,
       cat.category_name            AS category,
       COUNT(DISTINCT o.order_id)   AS orders,
       SUM(oi.quantity)             AS items_sold,
       SUM(oi.subtotal)             AS revenue
  FROM orders o
  JOIN canteen c     ON c.canteen_id  = o.canteen_id
  JOIN order_item oi ON oi.order_id   = o.order_id
  JOIN menu_item m   ON m.item_id     = oi.item_id
  JOIN category cat  ON cat.category_id = m.category_id
 WHERE o.order_status <> 'CANCELLED'
 GROUP BY c.name, cat.category_name
HAVING SUM(oi.subtotal) > 0
 ORDER BY revenue DESC;
