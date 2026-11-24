\set QUIET on
\pset pager off
SET search_path TO munch, public;
\echo '=== 4. Stored procedures: place_order and process_payment ==='
\echo '(runs inside a transaction and rolls back, so your data stays clean)'
BEGIN;
\echo
\echo '-- CALL place_order(student 1, canteen 1, 2 x Chhole Bhature + 1 x Maggi)'
CALL place_order(1, 1, '[{"item_id":3,"qty":2},{"item_id":14,"qty":1}]'::jsonb, NULL) \gset
\echo
SELECT order_id, order_status, total_amount FROM orders WHERE order_id = :p_order_id;
SELECT oi.line_no, m.item_name, oi.quantity, oi.price_at_order, oi.subtotal
  FROM order_item oi JOIN menu_item m ON m.item_id = oi.item_id
 WHERE oi.order_id = :p_order_id ORDER BY oi.line_no;
\echo
\echo '-- CALL process_payment(order, UPI)'
CALL process_payment(:p_order_id, 'upi', NULL);
SELECT p.payment_id, p.order_id, p.amount, p.payment_method, p.payment_status
  FROM payment p WHERE p.order_id = :p_order_id;
SELECT order_id, order_status, total_amount FROM orders WHERE order_id = :p_order_id;
\echo
\echo '-- Paying again is rejected'
SAVEPOINT before_double_pay;
CALL process_payment(:p_order_id, 'upi', NULL);
ROLLBACK TO SAVEPOINT before_double_pay;
ROLLBACK;
