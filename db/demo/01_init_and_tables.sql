\set QUIET on
\pset pager off
\echo '=== 1. Database initialization and table listing ==='
\echo
\echo '-- Schemas in the database'
\dn munch
\echo '-- Tables in schema munch'
\dt munch.*
\echo '-- Row count per table'
SET search_path TO munch, public;
SELECT 'student' AS table_name, COUNT(*) AS rows FROM student
UNION ALL SELECT 'canteen', COUNT(*) FROM canteen
UNION ALL SELECT 'category', COUNT(*) FROM category
UNION ALL SELECT 'menu_item', COUNT(*) FROM menu_item
UNION ALL SELECT 'inventory_item', COUNT(*) FROM inventory_item
UNION ALL SELECT 'recipe', COUNT(*) FROM recipe
UNION ALL SELECT 'supplier', COUNT(*) FROM supplier
UNION ALL SELECT 'purchase', COUNT(*) FROM purchase
UNION ALL SELECT 'staff', COUNT(*) FROM staff
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_item', COUNT(*) FROM order_item
UNION ALL SELECT 'payment', COUNT(*) FROM payment
UNION ALL SELECT 'review', COUNT(*) FROM review
UNION ALL SELECT 'restock_alert', COUNT(*) FROM restock_alert
UNION ALL SELECT 'order_audit_log', COUNT(*) FROM order_audit_log
ORDER BY 1;
