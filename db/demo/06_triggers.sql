\set QUIET on
\pset pager off
SET search_path TO munch, public;
\echo '=== 6. Triggers: stock deduction, restoration and audit logging ==='
\echo '(runs inside a transaction and rolls back, so your data stays clean)'
BEGIN;
\echo
\echo '-- Stock BEFORE the order (Cooking Oil, Bhature Flour, Chickpeas)'
SELECT inventory_id, item_name, quantity_available FROM inventory_item WHERE inventory_id IN (2, 8, 9) ORDER BY 1;
CALL place_order(1, 1, '[{"item_id":3,"qty":5}]'::jsonb, NULL) \gset
\echo
\echo '-- Stock AFTER placing 5 x Chhole Bhature (trigger t3 deducted ingredients)'
SELECT inventory_id, item_name, quantity_available FROM inventory_item WHERE inventory_id IN (2, 8, 9) ORDER BY 1;
\echo
\echo '-- Trigger t1 + t2: price snapshot and total'
SELECT oi.line_no, oi.quantity, oi.price_at_order, oi.subtotal, o.total_amount
  FROM order_item oi JOIN orders o ON o.order_id = oi.order_id WHERE oi.order_id = :p_order_id;
CALL process_payment(:p_order_id, 'card', NULL);
CALL cancel_order(:p_order_id);
\echo
\echo '-- Stock AFTER cancelling (trigger t3b restored ingredients)'
SELECT inventory_id, item_name, quantity_available FROM inventory_item WHERE inventory_id IN (2, 8, 9) ORDER BY 1;
\echo
\echo '-- Audit log (trigger t6) and refund'
SELECT log_id, order_id, old_status, new_status, changed_at FROM order_audit_log WHERE order_id = :p_order_id ORDER BY log_id;
SELECT payment_status FROM payment WHERE order_id = :p_order_id;
\echo
\echo '-- Status state machine (trigger t7): CANCELLED -> COMPLETED is rejected'
SAVEPOINT before_bad_update;
UPDATE orders SET order_status = 'COMPLETED' WHERE order_id = :p_order_id;
ROLLBACK TO SAVEPOINT before_bad_update;
ROLLBACK;
