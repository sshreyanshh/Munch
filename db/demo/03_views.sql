\set QUIET on
\pset pager off
\x auto
SET search_path TO munch, public;
\echo '=== 3. Views and materialized view ==='
\echo
\echo '-- v_order_details'
SELECT order_id, order_status, total_amount, student_name, canteen_name, item_name, quantity, subtotal, payment_method, payment_status
  FROM v_order_details ORDER BY order_id, line_no LIMIT 5;
\echo '-- v_low_stock'
SELECT item_name, quantity_available, reorder_level, shortfall, urgency_level, resolved FROM v_low_stock;
\echo '-- v_item_ratings (top 5)'
SELECT item_name, category_name, price, avg_rating, total_reviews FROM v_item_ratings ORDER BY avg_rating DESC, total_reviews DESC, item_name LIMIT 5;
\echo '-- mv_daily_sales (materialized view)'
REFRESH MATERIALIZED VIEW mv_daily_sales;
SELECT sales_date, canteen_name, total_orders, total_items_sold, gross_sales, completed_orders FROM mv_daily_sales ORDER BY sales_date;
