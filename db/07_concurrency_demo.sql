SELECT session_name, command
FROM (VALUES
    ('setup', 'UPDATE munch.inventory_item SET quantity_available = 1 WHERE inventory_id = 1;'),
    ('setup', 'UPDATE munch.menu_item SET availability_status = TRUE WHERE item_id = 1;'),
    ('session_a', 'BEGIN;'),
    ('session_a', $$CALL munch.place_order(1, 1, '[{"item_id": 1, "qty": 1}]'::jsonb, NULL);$$),
    ('session_b', 'BEGIN;'),
    ('session_b', $$CALL munch.place_order(2, 1, '[{"item_id": 1, "qty": 1}]'::jsonb, NULL);$$),
    ('session_b', 'ROLLBACK;'),
    ('session_a', 'COMMIT;'),
    ('verify', 'SELECT inventory_id, quantity_available FROM munch.inventory_item WHERE inventory_id = 1;'),
    ('verify', 'SELECT order_id, order_status, total_amount FROM munch.orders ORDER BY order_id DESC LIMIT 2;'),
    ('session_a_read_committed', 'BEGIN ISOLATION LEVEL READ COMMITTED;'),
    ('session_a_read_committed', 'SELECT quantity_available FROM munch.inventory_item WHERE inventory_id = 1;'),
    ('session_a_read_committed', 'SELECT quantity_available FROM munch.inventory_item WHERE inventory_id = 1;'),
    ('session_a_read_committed', 'COMMIT;'),
    ('session_b_update', 'BEGIN;'),
    ('session_b_update', 'UPDATE munch.inventory_item SET quantity_available = quantity_available + 1 WHERE inventory_id = 1;'),
    ('session_b_update', 'COMMIT;'),
    ('session_a_serializable', 'BEGIN ISOLATION LEVEL SERIALIZABLE;'),
    ('session_a_serializable', 'SELECT quantity_available FROM munch.inventory_item WHERE inventory_id = 1;'),
    ('session_a_serializable', 'UPDATE munch.inventory_item SET quantity_available = quantity_available + 1 WHERE inventory_id = 1;'),
    ('session_a_serializable', 'COMMIT;')
) AS demo(session_name, command);
