SET search_path TO munch, public;
SELECT
    o.order_id,
    s.name AS student_name,
    s.department,
    c.name AS canteen_name,
    m.item_name,
    oi.quantity,
    oi.price_at_order,
    oi.subtotal,
    o.order_date
FROM orders o
INNER JOIN student s ON s.student_id = o.student_id
INNER JOIN canteen c ON c.canteen_id = o.canteen_id
INNER JOIN order_item oi ON oi.order_id = o.order_id
INNER JOIN menu_item m ON m.item_id = oi.item_id
ORDER BY o.order_id DESC, oi.line_no;
SELECT
    m.item_id,
    m.item_name,
    c.name AS canteen_name,
    cat.category_name,
    m.price,
    COUNT(r.review_id) AS total_reviews,
    COALESCE(ROUND(AVG(r.rating)::NUMERIC, 2), 0.00) AS average_rating
FROM menu_item m
INNER JOIN canteen c ON c.canteen_id = m.canteen_id
INNER JOIN category cat ON cat.category_id = m.category_id
LEFT JOIN review r ON r.item_id = m.item_id
GROUP BY m.item_id, m.item_name, c.name, cat.category_name, m.price
ORDER BY average_rating DESC, total_reviews DESC;

SELECT
    s.supplier_id,
    s.name AS supplier_name,
    s.email,
    p.purchase_id,
    p.quantity,
    p.cost,
    p.purchase_date
FROM purchase p
RIGHT OUTER JOIN supplier s ON s.supplier_id = p.supplier_id
ORDER BY s.supplier_id, p.purchase_date DESC NULLS LAST;

SELECT
    m.item_id AS menu_item_id,
    m.item_name AS menu_item_name,
    i.inventory_id,
    i.item_name AS inventory_item_name,
    rc.qty_used,
    i.unit
FROM menu_item m
FULL OUTER JOIN recipe rc ON rc.item_id = m.item_id
FULL OUTER JOIN inventory_item i ON i.inventory_id = rc.inventory_id
ORDER BY m.item_id NULLS LAST, i.inventory_id NULLS LAST;

SELECT
    m.item_id,
    m.item_name,
    c.category_name,
    m.price,
    ROUND(cat_avg.avg_cat_price, 2) AS category_average_price,
    ROUND(m.price - cat_avg.avg_cat_price, 2) AS price_premium
FROM menu_item m
JOIN category c ON c.category_id = m.category_id
JOIN (
    SELECT category_id, AVG(price) AS avg_cat_price
    FROM menu_item
    GROUP BY category_id
) cat_avg ON cat_avg.category_id = m.category_id
WHERE m.price > cat_avg.avg_cat_price
ORDER BY price_premium DESC;

SELECT
    s.student_id,
    s.name AS student_name,
    s.department,
    s.year,
    (
        SELECT COALESCE(SUM(o.total_amount), 0.00)
        FROM orders o
        WHERE o.student_id = s.student_id
          AND o.order_status <> 'CANCELLED'
    ) AS student_total_spend
FROM student s
WHERE (
    SELECT COALESCE(SUM(o.total_amount), 0.00)
    FROM orders o
    WHERE o.student_id = s.student_id
      AND o.order_status <> 'CANCELLED'
) > (
    SELECT COALESCE(AVG(total_spent), 0.00)
    FROM (
        SELECT student_id, SUM(total_amount) AS total_spent
        FROM orders
        WHERE order_status <> 'CANCELLED'
        GROUP BY student_id
    ) avg_student_pool
)
ORDER BY student_total_spend DESC;

SELECT
    c.canteen_id,
    c.name AS canteen_name,
    c.location,
    COUNT(o.order_id) AS total_completed_orders,
    SUM(o.total_amount) AS total_revenue,
    ROUND(AVG(o.total_amount), 2) AS average_order_value
FROM canteen c
JOIN orders o ON o.canteen_id = c.canteen_id
WHERE o.order_status = 'COMPLETED'
GROUP BY c.canteen_id, c.name, c.location
HAVING SUM(o.total_amount) > 300.00
ORDER BY total_revenue DESC;

SELECT
    m.item_id,
    m.item_name,
    cat.category_name,
    SUM(oi.quantity) AS total_quantity_ordered,
    COUNT(DISTINCT oi.order_id) AS distinct_orders_count,
    SUM(oi.subtotal) AS gross_sales_value
FROM order_item oi
JOIN menu_item m ON m.item_id = oi.item_id
JOIN category cat ON cat.category_id = m.category_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'CANCELLED'
GROUP BY m.item_id, m.item_name, cat.category_name
HAVING SUM(oi.quantity) > 1
ORDER BY total_quantity_ordered DESC, gross_sales_value DESC;

WITH DeptSpend AS (
    SELECT
        s.department,
        COUNT(DISTINCT s.student_id) AS total_students_in_dept,
        COUNT(DISTINCT o.order_id) AS orders_placed,
        COALESCE(SUM(o.total_amount), 0.00) AS dept_gross_spend
    FROM student s
    LEFT JOIN orders o ON o.student_id = s.student_id AND o.order_status <> 'CANCELLED'
    GROUP BY s.department
),
CampusTotal AS (
    SELECT SUM(dept_gross_spend) AS total_campus_spend FROM DeptSpend
)
SELECT
    ds.department,
    ds.total_students_in_dept,
    ds.orders_placed,
    ds.dept_gross_spend,
    ROUND((ds.dept_gross_spend / NULLIF(ct.total_campus_spend, 0)) * 100, 2) AS spend_percentage
FROM DeptSpend ds
CROSS JOIN CampusTotal ct
ORDER BY ds.dept_gross_spend DESC;

WITH RECURSIVE DateCalendar AS (
    SELECT (CURRENT_DATE - INTERVAL '6 days')::DATE AS report_date
    UNION ALL
    SELECT (report_date + INTERVAL '1 day')::DATE
    FROM DateCalendar
    WHERE report_date < CURRENT_DATE
),
DailyRevenue AS (
    SELECT
        order_date,
        COUNT(order_id) AS orders_count,
        SUM(total_amount) AS revenue
    FROM orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY order_date
)
SELECT
    dc.report_date,
    TO_CHAR(dc.report_date, 'Dy, Mon DD') AS formatted_day,
    COALESCE(dr.orders_count, 0) AS orders_placed,
    COALESCE(dr.revenue, 0.00) AS revenue_earned,
    CASE WHEN dr.orders_count IS NULL THEN 'NO ACTIVITY' ELSE 'ACTIVE TRADING' END AS status_flag
FROM DateCalendar dc
LEFT JOIN DailyRevenue dr ON dr.order_date = dc.report_date
ORDER BY dc.report_date;

SELECT
    cat.category_name,
    m.item_name,
    COALESCE(SUM(oi.quantity), 0) AS total_units_sold,
    COALESCE(SUM(oi.subtotal), 0.00) AS total_revenue,
    RANK() OVER (
        PARTITION BY cat.category_id
        ORDER BY COALESCE(SUM(oi.quantity), 0) DESC
    ) AS category_sales_rank,
    DENSE_RANK() OVER (
        PARTITION BY cat.category_id
        ORDER BY COALESCE(SUM(oi.subtotal), 0.00) DESC
    ) AS category_revenue_rank
FROM menu_item m
JOIN category cat ON cat.category_id = m.category_id
LEFT JOIN order_item oi ON oi.item_id = m.item_id
LEFT JOIN orders o ON o.order_id = oi.order_id AND o.order_status <> 'CANCELLED'
GROUP BY cat.category_id, cat.category_name, m.item_id, m.item_name
ORDER BY cat.category_name, category_sales_rank;

WITH CanteenDaily AS (
    SELECT
        c.canteen_id,
        c.name AS canteen_name,
        o.order_date,
        SUM(o.total_amount) AS daily_revenue
    FROM orders o
    JOIN canteen c ON c.canteen_id = o.canteen_id
    WHERE o.order_status <> 'CANCELLED'
    GROUP BY c.canteen_id, c.name, o.order_date
)
SELECT
    canteen_name,
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        PARTITION BY canteen_id
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_running_revenue
FROM CanteenDaily
ORDER BY canteen_name, order_date;


WITH DailyAgg AS (
    SELECT
        order_date,
        SUM(total_amount) AS daily_revenue,
        COUNT(order_id) AS orders_count
    FROM orders
    WHERE order_status <> 'CANCELLED'
    GROUP BY order_date
)
SELECT
    order_date,
    daily_revenue,
    LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS previous_day_revenue,
    daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY order_date) AS revenue_change,
    ROUND(
        ((daily_revenue - LAG(daily_revenue, 1) OVER (ORDER BY order_date)) /
         NULLIF(LAG(daily_revenue, 1) OVER (ORDER BY order_date), 0)) * 100,
        2
    ) AS percentage_growth
FROM DailyAgg
ORDER BY order_date;

SELECT
    s.student_id,
    s.name,
    s.email,
    s.department,
    'Never Ordered' AS student_status
FROM student s
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.student_id = s.student_id
);

SELECT
    c.canteen_id,
    c.name,
    c.location
FROM canteen c
WHERE EXISTS (
    SELECT 1
    FROM inventory_item i
    JOIN restock_alert ra ON ra.inventory_id = i.inventory_id
    WHERE i.canteen_id = c.canteen_id AND NOT ra.resolved
);

-- students who ordered both snacks and beverages 
SELECT s.student_id, s.name, s.department
FROM student s
WHERE s.student_id IN (
    SELECT o.student_id
    FROM orders o
    JOIN order_item oi ON oi.order_id = o.order_id
    JOIN menu_item m ON m.item_id = oi.item_id
    JOIN category cat ON cat.category_id = m.category_id
    WHERE cat.category_name = 'SNACKS'
    INTERSECT
    SELECT o.student_id
    FROM orders o
    JOIN order_item oi ON oi.order_id = o.order_id
    JOIN menu_item m ON m.item_id = oi.item_id
    JOIN category cat ON cat.category_id = m.category_id
    WHERE cat.category_name = 'BEVERAGES'
);

-- students who ordered snacks but never ordered beverages:
SELECT s.student_id, s.name, s.department
FROM student s
WHERE s.student_id IN (
    SELECT o.student_id
    FROM orders o
    JOIN order_item oi ON oi.order_id = o.order_id
    JOIN menu_item m ON m.item_id = oi.item_id
    JOIN category cat ON cat.category_id = m.category_id
    WHERE cat.category_name = 'SNACKS'
    EXCEPT
    SELECT o.student_id
    FROM orders o
    JOIN order_item oi ON oi.order_id = o.order_id
    JOIN menu_item m ON m.item_id = oi.item_id
    JOIN category cat ON cat.category_id = m.category_id
    WHERE cat.category_name = 'BEVERAGES'
);

SELECT
    s.student_id,
    s.name,
    s.department,
    COALESCE(SUM(o.total_amount), 0.00) AS lifetime_spend,
    COUNT(o.order_id) AS total_orders,
    CASE
        WHEN COALESCE(SUM(o.total_amount), 0.00) >= 300.00 THEN 'Platinum Diner (Top Spender)'
        WHEN COALESCE(SUM(o.total_amount), 0.00) >= 150.00 THEN 'Gold Diner (Regular)'
        WHEN COALESCE(SUM(o.total_amount), 0.00) > 0.00   THEN 'Silver Diner (Occasional)'
        ELSE 'Bronze (New / Inactive)'
    END AS loyalty_tier
FROM student s
LEFT JOIN orders o ON o.student_id = s.student_id AND o.order_status <> 'CANCELLED'
GROUP BY s.student_id, s.name, s.department
ORDER BY lifetime_spend DESC;


SELECT
    EXTRACT(HOUR FROM o.order_time)::INT AS order_hour_24,
    TO_CHAR(
        ('2026-01-01 ' || EXTRACT(HOUR FROM o.order_time) || ':00:00')::TIMESTAMP,
        'HH12:00 AM'
    ) AS time_slot,
    COUNT(o.order_id) AS orders_count,
    SUM(o.total_amount) AS revenue_collected,
    ROUND(AVG(o.total_amount), 2) AS avg_ticket_size,
    CASE
        WHEN EXTRACT(HOUR FROM o.order_time) BETWEEN 8 AND 10 THEN 'Morning Breakfast Rush'
        WHEN EXTRACT(HOUR FROM o.order_time) BETWEEN 12 AND 14 THEN 'Afternoon Lunch Peak'
        WHEN EXTRACT(HOUR FROM o.order_time) BETWEEN 16 AND 18 THEN 'Evening Snack Break'
        WHEN EXTRACT(HOUR FROM o.order_time) >= 20 THEN 'Night / Hostel Munchies'
        ELSE 'Regular Hours'
    END AS campus_rush_category
FROM orders o
WHERE o.order_status <> 'CANCELLED'
GROUP BY EXTRACT(HOUR FROM o.order_time)
ORDER BY orders_count DESC, revenue_collected DESC;
