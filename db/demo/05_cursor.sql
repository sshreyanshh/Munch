\set QUIET on
\pset pager off
SET search_path TO munch, public;
\echo '=== 5. Cursor function: inventory restock suggestions ==='
\echo
\echo '-- Items at or below reorder level'
SELECT * FROM get_low_stock_items(1);
\echo
\echo '-- generate_restock_suggestions(canteen 1): loops with an explicit CURSOR'
SELECT * FROM generate_restock_suggestions(1);
\echo
\echo '-- Simulate Full Cream Milk running low (trigger t4 raises an alert), then ask again'
BEGIN;
UPDATE inventory_item SET quantity_available = 3 WHERE inventory_id = 5;
SELECT alert_id, inventory_id, quantity_at_alert, resolved FROM restock_alert WHERE inventory_id = 5 AND NOT resolved;
SELECT * FROM generate_restock_suggestions(1) ORDER BY inventory_id;
ROLLBACK;
