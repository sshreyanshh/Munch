SET search_path TO munch, public;

TRUNCATE TABLE order_audit_log, restock_alert, review, purchase, payment, order_item, orders, recipe, staff, inventory_item, menu_item, supplier, category, canteen, student RESTART IDENTITY CASCADE;

INSERT INTO student (name, email, phone, department, year) VALUES
('Rushil Koul', 'rushil.koul@jiit.ac.in', '9811223344', 'CSE', 3),
('Shreyansh Srivastava', 'shreyansh.s@jiit.ac.in', '9822334455', 'CSE', 3),
('Aarav Sharma', 'aarav.sharma@jiit.ac.in', '9833445566', 'IT', 2),
('Diya Verma', 'diya.verma@jiit.ac.in', '9844556677', 'ECE', 4),
('Kabir Mehta', 'kabir.mehta@jiit.ac.in', '9855667788', 'Biotech', 1),
('Ananya Gupta', 'ananya.gupta@jiit.ac.in', '9866778899', 'CSE', 2),
('Rohan Malhotra', 'rohan.m@jiit.ac.in', '9877889900', 'IT', 3),
('Ishita Saxena', 'ishita.saxena@jiit.ac.in', '9888990011', 'ECE', 1),
('Siddharth Joshi', 'sid.joshi@jiit.ac.in', '9899001122', 'Biotech', 4),
('Tanvi Rajput', 'tanvi.rajput@jiit.ac.in', '9810111213', 'CSE', 4);

INSERT INTO canteen (name, location, contact, opening_time, closing_time) VALUES
('JIIT Annapurna', 'Ground Floor, ABB-III, Sector 62, Noida', '01202400101', '08:00:00', '22:00:00');

INSERT INTO category (category_name) VALUES
('CHAT-PATI CHAAT'),
('SNACKS'),
('COMBO MEAL'),
('SOUTH INDIAN'),
('CHINESE'),
('BEVERAGES'),
('ICE CREAMS'),
('JUICES'),
('FLAVOURED MILK'),
('BISCUITS/CAKE'),
('CHIPS'),
('PIZZA');

INSERT INTO supplier (name, phone, email, address) VALUES
('Mother Dairy Delhi Milk Scheme', '01122445566', 'orders@motherdairy.com', 'Patparganj Industrial Area, Delhi'),
('Haldiram Foods Supply Ltd', '01204567890', 'bulk@haldirams.com', 'Sector 63, Noida, UP'),
('Nestle Professional India', '01244556677', 'institutions@nestle.in', 'DLF Cyber City, Gurugram'),
('Verma Farm Fresh Vegetables', '9811122233', 'verma.fresh@gmail.com', 'Mandi Phase 2, Noida Sector 88'),
('Britannia B2B Distributors', '01129887766', 'b2b@britannia.co.in', 'Okhla Industrial Area Phase 1, New Delhi'),
('Dharampal Premchand Spices', '01141234567', 'sales@catchfoods.com', 'Mayapuri Industrial Area, New Delhi');

INSERT INTO menu_item (category_id, canteen_id, item_name, description, price, availability_status) VALUES
(1, 1, 'Bhel Puri', 'Freshly served Bhel Puri at JIIT Annapurna', 40.00, TRUE),
(1, 1, 'Channa Kulcha', 'Freshly served Channa Kulcha at JIIT Annapurna', 50.00, TRUE),
(1, 1, 'Chhole Bhature', 'Freshly served Chhole Bhature at JIIT Annapurna', 80.00, TRUE),
(1, 1, 'Papdi Chaat', 'Freshly served Papdi Chaat at JIIT Annapurna', 40.00, TRUE),
(1, 1, 'Tikki Chaat', 'Freshly served Tikki Chaat at JIIT Annapurna', 40.00, TRUE),
(2, 1, 'Boiled Egg 2 Pcs', 'Freshly served Boiled Egg 2 Pcs at JIIT Annapurna', 25.00, TRUE),
(2, 1, 'Bread Omelette', 'Freshly served Bread Omelette at JIIT Annapurna', 40.00, TRUE),
(2, 1, 'Bread Pakora', 'Freshly served Bread Pakora at JIIT Annapurna', 30.00, TRUE),
(2, 1, 'Bread Roll', 'Freshly served Bread Roll at JIIT Annapurna', 30.00, TRUE),
(2, 1, 'Dahi Bhalla', 'Freshly served Dahi Bhalla at JIIT Annapurna', 40.00, TRUE),
(2, 1, 'Egg Roll', 'Freshly served Egg Roll at JIIT Annapurna', 50.00, TRUE),
(2, 1, 'French Fries', 'Freshly served French Fries at JIIT Annapurna', 40.00, TRUE),
(2, 1, 'Kachori (With Aloo ki Sabzi)', 'Freshly served Kachori (With Aloo ki Sabzi) at JIIT Annapurna', 45.00, TRUE),
(2, 1, 'Maggi Noodles', 'Freshly served Maggi Noodles at JIIT Annapurna', 35.00, TRUE),
(2, 1, 'Mixed Veg Pakoda', 'Freshly served Mixed Veg Pakoda at JIIT Annapurna', 40.00, TRUE),
(2, 1, 'Paneer Kulcha', 'Freshly served Paneer Kulcha at JIIT Annapurna', 60.00, TRUE),
(2, 1, 'Paneer Patty', 'Freshly served Paneer Patty at JIIT Annapurna', 40.00, TRUE),
(2, 1, 'Samosa', 'Freshly served Samosa at JIIT Annapurna', 10.00, TRUE),
(2, 1, 'Vada Pav', 'Freshly served Vada Pav at JIIT Annapurna', 45.00, TRUE),
(2, 1, 'Veg Burger', 'Freshly served Veg Burger at JIIT Annapurna', 40.00, TRUE),
(2, 1, 'Veg Grill Sandwich', 'Freshly served Veg Grill Sandwich at JIIT Annapurna', 75.00, TRUE),
(2, 1, 'Veg Hot Dog', 'Freshly served Veg Hot Dog at JIIT Annapurna', 45.00, TRUE),
(2, 1, 'Veg Paneer Roll', 'Freshly served Veg Paneer Roll at JIIT Annapurna', 45.00, TRUE),
(2, 1, 'Veg Patty', 'Freshly served Veg Patty at JIIT Annapurna', 35.00, TRUE),
(2, 1, 'Veg Sandwich', 'Freshly served Veg Sandwich at JIIT Annapurna', 30.00, TRUE),
(3, 1, 'Aloo Parantha with Curd', 'Freshly served Aloo Parantha with Curd at JIIT Annapurna', 50.00, TRUE),
(3, 1, 'Paneer Parantha with Curd', 'Freshly served Paneer Parantha with Curd at JIIT Annapurna', 70.00, TRUE),
(4, 1, 'Dosa (Masala)', 'Freshly served Dosa (Masala) at JIIT Annapurna', 60.00, TRUE),
(4, 1, 'Mix Uttapam', 'Freshly served Mix Uttapam at JIIT Annapurna', 60.00, TRUE),
(4, 1, 'Sambhar Vada', 'Freshly served Sambhar Vada at JIIT Annapurna', 45.00, TRUE),
(5, 1, 'Veg Fried Momos', 'Freshly served Veg Fried Momos at JIIT Annapurna', 60.00, TRUE),
(5, 1, 'Veg Manchurian', 'Freshly served Veg Manchurian at JIIT Annapurna', 80.00, TRUE),
(5, 1, 'Veg Momos', 'Freshly served Veg Momos at JIIT Annapurna', 40.00, TRUE),
(5, 1, 'Veg Noodles', 'Freshly served Veg Noodles at JIIT Annapurna', 55.00, TRUE),
(5, 1, 'Veg Spring Roll', 'Freshly served Veg Spring Roll at JIIT Annapurna', 80.00, TRUE),
(6, 1, 'Belgian Choco Shake', 'Freshly served Belgian Choco Shake at JIIT Annapurna', 50.00, TRUE),
(6, 1, 'Coconut Water', 'Freshly served Coconut Water at JIIT Annapurna', 50.00, FALSE),
(6, 1, 'Coffee', 'Freshly served Coffee at JIIT Annapurna', 20.00, TRUE),
(6, 1, 'Cold Coffee Frappe', 'Freshly served Cold Coffee Frappe at JIIT Annapurna', 40.00, TRUE),
(6, 1, 'Cold Drink', 'Freshly served Cold Drink at JIIT Annapurna', 20.00, TRUE),
(6, 1, 'Cold Drink Bottle', 'Freshly served Cold Drink Bottle at JIIT Annapurna', 40.00, TRUE),
(6, 1, 'Cookie Caramel Shake', 'Freshly served Cookie Caramel Shake at JIIT Annapurna', 65.00, TRUE),
(6, 1, 'Mineral Water', 'Freshly served Mineral Water at JIIT Annapurna', 20.00, TRUE),
(6, 1, 'Nimbooz', 'Freshly served Nimbooz at JIIT Annapurna', 25.00, TRUE),
(6, 1, 'Sweet Lassi', 'Freshly served Sweet Lassi at JIIT Annapurna', 30.00, TRUE),
(6, 1, 'Tea', 'Freshly served Tea at JIIT Annapurna', 10.00, TRUE),
(7, 1, 'Butter Scotch', 'Freshly served Butter Scotch at JIIT Annapurna', 35.00, TRUE),
(7, 1, 'Chillz Mango', 'Freshly served Chillz Mango at JIIT Annapurna', 30.00, TRUE),
(7, 1, 'Choco Bar', 'Freshly served Choco Bar at JIIT Annapurna', 25.00, TRUE),
(7, 1, 'Choco Chip Cup', 'Freshly served Choco Chip Cup at JIIT Annapurna', 35.00, TRUE),
(7, 1, 'Choco Cone', 'Freshly served Choco Cone at JIIT Annapurna', 40.00, TRUE),
(7, 1, 'Fruit Punch Lick', 'Freshly served Fruit Punch Lick at JIIT Annapurna', 20.00, TRUE),
(7, 1, 'Kulfi', 'Freshly served Kulfi at JIIT Annapurna', 30.00, TRUE),
(7, 1, 'Orange Lick', 'Freshly served Orange Lick at JIIT Annapurna', 15.00, TRUE),
(7, 1, 'Pista Kulfi', 'Freshly served Pista Kulfi at JIIT Annapurna', 35.00, TRUE),
(7, 1, 'Strawberry Cup', 'Freshly served Strawberry Cup at JIIT Annapurna', 25.00, TRUE),
(7, 1, 'Vanila Cup', 'Freshly served Vanila Cup at JIIT Annapurna', 20.00, TRUE),
(8, 1, 'Apple', 'Freshly served Apple at JIIT Annapurna', 30.00, TRUE),
(8, 1, 'Appy', 'Freshly served Appy at JIIT Annapurna', 20.00, TRUE),
(8, 1, 'Frooti', 'Freshly served Frooti at JIIT Annapurna', 20.00, TRUE),
(8, 1, 'Guava', 'Freshly served Guava at JIIT Annapurna', 30.00, TRUE),
(8, 1, 'Lichi', 'Freshly served Lichi at JIIT Annapurna', 30.00, TRUE),
(8, 1, 'Mixed Fruit', 'Freshly served Mixed Fruit at JIIT Annapurna', 30.00, TRUE),
(8, 1, 'Orange', 'Freshly served Orange at JIIT Annapurna', 30.00, TRUE),
(8, 1, 'Pineapple', 'Freshly served Pineapple at JIIT Annapurna', 30.00, TRUE),
(9, 1, 'Chocolate', 'Freshly served Chocolate at JIIT Annapurna', 35.00, TRUE),
(9, 1, 'Cold Coffee', 'Freshly served Cold Coffee at JIIT Annapurna', 35.00, TRUE),
(9, 1, 'Kesar Elaichi', 'Freshly served Kesar Elaichi at JIIT Annapurna', 35.00, TRUE),
(10, 1, '50-50 Biscuit', 'Freshly served 50-50 Biscuit at JIIT Annapurna', 15.00, TRUE),
(10, 1, 'Bourbon (medium)', 'Freshly served Bourbon (medium) at JIIT Annapurna', 30.00, TRUE),
(10, 1, 'Bourbon (small)', 'Freshly served Bourbon (small) at JIIT Annapurna', 15.00, TRUE),
(10, 1, 'Cake (medium)', 'Freshly served Cake (medium) at JIIT Annapurna', 40.00, TRUE),
(10, 1, 'Cake (small)', 'Freshly served Cake (small) at JIIT Annapurna', 20.00, TRUE),
(10, 1, 'Good Day', 'Freshly served Good Day at JIIT Annapurna', 25.00, TRUE),
(10, 1, 'Nutri Choice', 'Freshly served Nutri Choice at JIIT Annapurna', 30.00, TRUE),
(10, 1, 'Pure Magic', 'Freshly served Pure Magic at JIIT Annapurna', 35.00, TRUE),
(10, 1, 'Time Pass', 'Freshly served Time Pass at JIIT Annapurna', 15.00, TRUE),
(11, 1, 'Kurkure', 'Freshly served Kurkure at JIIT Annapurna', 20.00, TRUE),
(11, 1, 'Kurkure Masala Munch', 'Freshly served Kurkure Masala Munch at JIIT Annapurna', 20.00, TRUE),
(11, 1, 'Lays'' Classic Salted', 'Freshly served Lays'' Classic Salted at JIIT Annapurna', 20.00, TRUE),
(11, 1, 'Lays'' American Style Cream & Onion', 'Freshly served Lays'' American Style Cream & Onion at JIIT Annapurna', 20.00, TRUE),
(11, 1, 'Lays'' India''s Magic Masala', 'Freshly served Lays'' India''s Magic Masala at JIIT Annapurna', 20.00, TRUE),
(11, 1, 'Lays'' Spanish Tomato Tango', 'Freshly served Lays'' Spanish Tomato Tango at JIIT Annapurna', 20.00, TRUE),
(12, 1, 'Onion Capsicum', 'Freshly served Onion Capsicum at JIIT Annapurna', 110.00, TRUE);

INSERT INTO inventory_item (canteen_id, item_name, quantity_available, unit, reorder_level) VALUES
(1, 'Potatoes (Aloo)', 45.00, 'kg', 20.00),
(1, 'Cooking Oil', 50.00, 'L', 20.00),
(1, 'Refined Flour (Maida)', 35.00, 'kg', 15.00),
(1, 'Fresh Paneer', 12.00, 'kg', 10.00),
(1, 'Full Cream Milk', 8.00, 'L', 15.00),                 -- low stock (8 <= 15) -> trigger t4 alert
(1, 'Tea Leaves', 3.50, 'kg', 5.00),                       -- low stock (3.5 <= 5) -> trigger t4 alert
(1, 'Coffee Powder', 6.00, 'kg', 4.00),
(1, 'Bhature Flour & Yeast', 25.00, 'kg', 10.00),
(1, 'Chickpeas (Kabuli Chana)', 30.00, 'kg', 15.00),
(1, 'Bread Loaves', 6.00, 'pack', 10.00),                  -- low stock (6 <= 10) -> trigger t4 alert
(1, 'Fresh Eggs', 40.00, 'pcs', 20.00),
(1, 'Dosa & Idli Batter', 18.00, 'kg', 10.00),
(1, 'Sambar Dal & Spices', 15.00, 'kg', 8.00),
(1, 'Maggi Noodle Packs', 80.00, 'pack', 30.00),
(1, 'Hakka Noodles Mix', 20.00, 'kg', 10.00),
(1, 'Momos Sheet Dough', 15.00, 'kg', 8.00),
(1, 'Burger Buns & Patties', 30.00, 'pack', 15.00),
(1, 'Amul Table Butter', 8.00, 'kg', 5.00),
(1, 'Pizza Dough & Mozzarella', 12.00, 'kg', 8.00),
(1, 'Fresh Onion & Capsicum', 25.00, 'kg', 10.00),
(1, 'Packaged Ice Creams', 50.00, 'pack', 20.00),
(1, 'Packaged Juices & Drinks', 60.00, 'pack', 25.00),
(1, 'Packaged Chips & Biscuits', 75.00, 'pack', 30.00);

INSERT INTO staff (canteen_id, name, role, phone) VALUES
(1, 'Ramesh Chandra', 'Canteen General Manager', '9811001001'),
(1, 'Baldev Singh', 'Head Chef', '9811001002'),
(1, 'Sunil Kumar', 'Billing Cashier', '9811001003'),
(1, 'Vikram Rawat', 'Snack & Chaat Specialist', '9811001004'),
(1, 'Deepak Verma', 'South Indian & Chinese Chef', '9811001005');


INSERT INTO recipe (item_id, inventory_id, qty_used) VALUES
-- samosa (item_id 18) -> potatoes (1), maida (3), cooking oil (2)
(18, 1, 0.100),
(18, 3, 0.050),
(18, 2, 0.040),

-- chhole bhature (item_id 3) -> chana (9), bhature flour (8), oil (2)
(3, 9, 0.150),
(3, 8, 0.100),
(3, 2, 0.060),

-- bread pakora (item_id 8) -> bread (10), potatoes (1), oil (2)
(8, 10, 0.200),
(8, 1, 0.080),
(8, 2, 0.050),

-- bread omelette (item_id 7) -> bread (10), eggs (11), butter (18)
(7, 10, 0.200),
(7, 11, 2.000),
(7, 18, 0.020),

-- french fries (item_id 12) -> potatoes (1), oil (2)
(12, 1, 0.200),
(12, 2, 0.080),

-- maggi noodles (item_id 14) -> maggi packs (14), butter (18)
(14, 14, 1.000),
(14, 18, 0.020),

-- veg burger (item_id 20) -> buns & patties (17), oil (2)
(20, 17, 1.000),
(20, 2, 0.030),

-- dosa (masala) (item_id 28) -> batter (12), potatoes (1), sambar dal (13)
(28, 12, 0.200),
(28, 1, 0.100),
(28, 13, 0.050),

-- veg fried momos (item_id 31) -> momos sheet (16), oil (2)
(31, 16, 0.150),
(31, 2, 0.050),

-- veg noodles (item_id 34) -> hakka noodles (15), oil (2)
(34, 15, 0.150),
(34, 2, 0.030),

-- tea (item_id 46) -> milk (5), tea leaves (6)
(46, 5, 0.120),
(46, 6, 0.015),

-- coffee (item_id 38) -> milk (5), coffee powder (7)
(38, 5, 0.120),
(38, 7, 0.015),

-- cold coffee frappe (item_id 39) -> milk (5), coffee powder (7)
(39, 5, 0.200),
(39, 7, 0.025),

-- belgian choco shake (item_id 36) -> milk (5)
(36, 5, 0.250),

-- onion capsicum pizza (item_id 84) -> pizza dough & cheese (19), onion & capsicum (20)
(84, 19, 0.250),
(84, 20, 0.100);

INSERT INTO purchase (supplier_id, inventory_id, canteen_id, quantity, purchase_date, cost) VALUES
(1, 5, 1, 30.00, CURRENT_DATE - INTERVAL '5 days', 1800.00),
(2, 9, 1, 20.00, CURRENT_DATE - INTERVAL '4 days', 2400.00),
(4, 1, 1, 50.00, CURRENT_DATE - INTERVAL '3 days', 1500.00),
(3, 7, 1, 10.00, CURRENT_DATE - INTERVAL '4 days', 1200.00),
(5, 10, 1, 50.00, CURRENT_DATE - INTERVAL '2 days', 1500.00),
(3, 14, 1, 100.00, CURRENT_DATE - INTERVAL '2 days', 2800.00);


INSERT INTO orders (student_id, canteen_id, order_date, order_time, order_status)
VALUES (1, 1, CURRENT_DATE - INTERVAL '2 days', '08:45:00', 'PLACED');
INSERT INTO order_item (order_id, line_no, item_id, quantity, price_at_order) VALUES
(1, 1, 18, 2, 10.00),  -- 2 x samosa (20)
(1, 2, 46, 2, 10.00);  -- 2 x tea (20) -> total: 40
UPDATE orders SET order_status = 'CONFIRMED' WHERE order_id = 1;
UPDATE orders SET order_status = 'PREPARING' WHERE order_id = 1;
UPDATE orders SET order_status = 'READY' WHERE order_id = 1;
UPDATE orders SET order_status = 'COMPLETED' WHERE order_id = 1;

INSERT INTO orders (student_id, canteen_id, order_date, order_time, order_status)
VALUES (2, 1, CURRENT_DATE - INTERVAL '1 days', '12:30:00', 'PLACED');
INSERT INTO order_item (order_id, line_no, item_id, quantity, price_at_order) VALUES
(2, 1, 3, 1, 80.00),   -- 1 x chhole bhature (80)
(2, 2, 45, 1, 30.00);  -- 1 x sweet lassi (30) -> total: 110
UPDATE orders SET order_status = 'CONFIRMED' WHERE order_id = 2;
UPDATE orders SET order_status = 'PREPARING' WHERE order_id = 2;
UPDATE orders SET order_status = 'READY' WHERE order_id = 2;
UPDATE orders SET order_status = 'COMPLETED' WHERE order_id = 2;

INSERT INTO payment (order_id, amount, payment_method, payment_status, payment_time) VALUES
(1, 40.00, 'UPI', 'SUCCESS', CURRENT_TIMESTAMP - INTERVAL '2 days 11 hours'),
(2, 110.00, 'CARD', 'SUCCESS', CURRENT_TIMESTAMP - INTERVAL '1 days 7 hours');

INSERT INTO review (student_id, item_id, rating, comment, review_date) VALUES
(1, 18, 5, 'best samosa at jp! maza aagaya.', CURRENT_DATE - INTERVAL '2 days'),
(2, 3, 5, 'cold coffee me kuch milaaya gaya hai. too tasty.', CURRENT_DATE - INTERVAL '1 days');

SELECT
    (SELECT COUNT(*) FROM student) AS students,
    (SELECT COUNT(*) FROM canteen) AS canteens,
    (SELECT COUNT(*) FROM category) AS categories,
    (SELECT COUNT(*) FROM supplier) AS suppliers,
    (SELECT COUNT(*) FROM menu_item) AS menu_items,
    (SELECT COUNT(*) FROM inventory_item) AS inventory_items,
    (SELECT COUNT(*) FROM recipe) AS recipes,
    (SELECT COUNT(*) FROM staff) AS staff,
    (SELECT COUNT(*) FROM purchase) AS purchases,
    (SELECT COUNT(*) FROM orders) AS orders,
    (SELECT COUNT(*) FROM order_item) AS order_items,
    (SELECT COUNT(*) FROM payment) AS payments,
    (SELECT COUNT(*) FROM review) AS reviews,
    (SELECT COUNT(*) FROM restock_alert) AS restock_alerts,
    (SELECT COUNT(*) FROM order_audit_log) AS audit_logs;
