SET search_path TO munch, public;

DROP VIEW IF EXISTS v_order_details CASCADE;
CREATE OR REPLACE VIEW v_order_details AS
SELECT
    o.order_id,
    o.order_date,
    o.order_time,
    o.order_status,
    o.total_amount,
    s.student_id,
    s.name AS student_name,
    s.email AS student_email,
    s.department AS student_dept,
    s.year AS student_year,
    c.canteen_id,
    c.name AS canteen_name,
    c.location AS canteen_location,
    oi.line_no,
    oi.item_id,
    m.item_name,
    cat.category_name,
    oi.quantity,
    oi.price_at_order,
    oi.subtotal,
    p.payment_id,
    p.payment_method,
    p.payment_status,
    p.payment_time
FROM orders o
JOIN student s ON s.student_id = o.student_id
JOIN canteen c ON c.canteen_id = o.canteen_id
JOIN order_item oi ON oi.order_id = o.order_id
JOIN menu_item m ON m.item_id = oi.item_id
JOIN category cat ON cat.category_id = m.category_id
LEFT JOIN payment p ON p.order_id = o.order_id;

COMMENT ON VIEW v_order_details IS 'denormalized view joining student, canteen, orders, line items, and payment details';


DROP VIEW IF EXISTS v_low_stock CASCADE;
CREATE OR REPLACE VIEW v_low_stock AS
SELECT
    i.inventory_id,
    i.canteen_id,
    c.name AS canteen_name,
    i.item_name,
    i.quantity_available,
    i.reorder_level,
    i.unit,
    (i.reorder_level - i.quantity_available) AS shortfall,
    CASE
        WHEN i.quantity_available = 0 THEN 'CRITICAL_DEPLETED'
        WHEN i.quantity_available <= (i.reorder_level * 0.5) THEN 'HIGH_ALERT'
        ELSE 'REORDER_NEEDED'
    END AS urgency_level,
    ra.alert_id,
    ra.alert_time,
    ra.resolved
FROM inventory_item i
JOIN canteen c ON c.canteen_id = i.canteen_id
LEFT JOIN restock_alert ra ON ra.inventory_id = i.inventory_id AND NOT ra.resolved
WHERE i.quantity_available <= i.reorder_level;

COMMENT ON VIEW v_low_stock IS 'operational view listing inventory items at or below reorder threshold with shortfall and alert status';

DROP VIEW IF EXISTS v_item_ratings CASCADE;
CREATE OR REPLACE VIEW v_item_ratings AS
SELECT
    m.item_id,
    m.item_name,
    m.canteen_id,
    c.name AS canteen_name,
    cat.category_id,
    cat.category_name,
    m.price,
    m.availability_status,
    COALESCE(ROUND(AVG(r.rating)::NUMERIC, 2), 0.00) AS avg_rating,
    COUNT(r.review_id) AS total_reviews,
    COUNT(CASE WHEN r.rating >= 4 THEN 1 END) AS positive_reviews
FROM menu_item m
JOIN canteen c ON c.canteen_id = m.canteen_id
JOIN category cat ON cat.category_id = m.category_id
LEFT JOIN review r ON r.item_id = m.item_id
GROUP BY m.item_id, m.item_name, m.canteen_id, c.name, cat.category_id, cat.category_name, m.price, m.availability_status;

COMMENT ON VIEW v_item_ratings IS 'aggregated rating and customer sentiment view per menu item';

DROP MATERIALIZED VIEW IF EXISTS mv_daily_sales CASCADE;
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
    o.order_date AS sales_date,
    c.canteen_id,
    c.name AS canteen_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(oi.quantity), 0) AS total_items_sold,
    COALESCE(SUM(o.total_amount), 0.00) AS gross_sales,
    COUNT(DISTINCT CASE WHEN o.order_status = 'COMPLETED' THEN o.order_id END) AS completed_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'CANCELLED' THEN o.order_id END) AS cancelled_orders
FROM orders o
JOIN canteen c ON c.canteen_id = o.canteen_id
LEFT JOIN order_item oi ON oi.order_id = o.order_id
LEFT JOIN payment p ON p.order_id = o.order_id AND p.payment_status = 'SUCCESS'
WHERE o.order_status <> 'CANCELLED'
GROUP BY o.order_date, c.canteen_id, c.name
WITH DATA;

CREATE UNIQUE INDEX idx_uq_mv_daily_sales ON mv_daily_sales (sales_date, canteen_id);

COMMENT ON MATERIALIZED VIEW mv_daily_sales IS 'materialized daily sales and revenue aggregations per canteen';

CREATE INDEX IF NOT EXISTS idx_orders_student_id ON orders (student_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders (order_date);
CREATE INDEX IF NOT EXISTS idx_order_item_item_id ON order_item (item_id);
CREATE INDEX IF NOT EXISTS idx_orders_canteen_status_date ON orders (canteen_id, order_status, order_date);
CREATE INDEX IF NOT EXISTS idx_menu_item_active
    ON menu_item (canteen_id, category_id)
    WHERE availability_status = TRUE;
CREATE INDEX IF NOT EXISTS idx_orders_active_queue
    ON orders (canteen_id, order_time)
    WHERE order_status IN ('PLACED', 'CONFIRMED', 'PREPARING', 'READY');
CREATE INDEX IF NOT EXISTS idx_review_item_id ON review (item_id);
