SET search_path TO munch, public;

CREATE OR REPLACE FUNCTION trg_order_item_before_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
DECLARE
    v_price NUMERIC(8,2);
    v_available BOOLEAN;
    v_name VARCHAR;
    v_item_canteen INT;
    v_order_canteen INT;
BEGIN
    SELECT m.price, m.availability_status, m.item_name, m.canteen_id
      INTO v_price, v_available, v_name, v_item_canteen
      FROM menu_item m
     WHERE m.item_id = NEW.item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Menu item % does not exist', NEW.item_id USING ERRCODE = 'MN002';
    END IF;

    IF NOT v_available THEN
        RAISE EXCEPTION 'Item "%" is currently unavailable', v_name USING ERRCODE = 'MN002';
    END IF;

    SELECT o.canteen_id INTO v_order_canteen FROM orders o WHERE o.order_id = NEW.order_id;

    IF v_order_canteen IS DISTINCT FROM v_item_canteen THEN
        RAISE EXCEPTION 'Item "%" is not sold at this canteen', v_name USING ERRCODE = 'MN002';
    END IF;

    NEW.price_at_order := v_price;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS t1_order_item_before_insert ON order_item;
CREATE TRIGGER t1_order_item_before_insert
BEFORE INSERT ON order_item
FOR EACH ROW EXECUTE FUNCTION trg_order_item_before_insert();


CREATE OR REPLACE FUNCTION trg_order_item_recalc_total()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
DECLARE
    v_order_id INT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_order_id := OLD.order_id;
    ELSE
        v_order_id := NEW.order_id;
    END IF;

    UPDATE orders
       SET total_amount = (SELECT COALESCE(SUM(oi.subtotal), 0)
                             FROM order_item oi
                            WHERE oi.order_id = v_order_id)
     WHERE order_id = v_order_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS t2_order_item_recalc_total ON order_item;
CREATE TRIGGER t2_order_item_recalc_total
AFTER INSERT OR UPDATE OR DELETE ON order_item
FOR EACH ROW EXECUTE FUNCTION trg_order_item_recalc_total();


CREATE OR REPLACE FUNCTION trg_order_item_deduct_stock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
DECLARE
    r RECORD;
    v_need NUMERIC;
    v_have NUMERIC;
    v_menu_name VARCHAR;
BEGIN
    SELECT m.item_name INTO v_menu_name FROM menu_item m WHERE m.item_id = NEW.item_id;

    FOR r IN
        SELECT rc.inventory_id, rc.qty_used
          FROM recipe rc
         WHERE rc.item_id = NEW.item_id
         ORDER BY rc.inventory_id
    LOOP
        v_need := r.qty_used * NEW.quantity;

        SELECT i.quantity_available INTO v_have
          FROM inventory_item i
         WHERE i.inventory_id = r.inventory_id
           FOR UPDATE;

        IF v_have < v_need THEN
            RAISE EXCEPTION 'Not enough stock to make % x "%"', NEW.quantity, v_menu_name
                USING ERRCODE = 'MN001';
        END IF;

        UPDATE inventory_item
           SET quantity_available = quantity_available - v_need
         WHERE inventory_id = r.inventory_id;
    END LOOP;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS t3_order_item_deduct_stock ON order_item;
CREATE TRIGGER t3_order_item_deduct_stock
AFTER INSERT ON order_item
FOR EACH ROW EXECUTE FUNCTION trg_order_item_deduct_stock();


CREATE OR REPLACE FUNCTION trg_order_cancel_restore_stock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
BEGIN
    UPDATE inventory_item i
       SET quantity_available = i.quantity_available + x.qty
      FROM (SELECT rc.inventory_id, SUM(oi.quantity * rc.qty_used) AS qty
              FROM order_item oi
              JOIN recipe rc ON rc.item_id = oi.item_id
             WHERE oi.order_id = NEW.order_id
             GROUP BY rc.inventory_id) x
     WHERE i.inventory_id = x.inventory_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS t3b_order_cancel_restore_stock ON orders;
CREATE TRIGGER t3b_order_cancel_restore_stock
AFTER UPDATE OF order_status ON orders
FOR EACH ROW
WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status AND NEW.order_status = 'CANCELLED')
EXECUTE FUNCTION trg_order_cancel_restore_stock();


CREATE OR REPLACE FUNCTION trg_inventory_low_stock_alert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
BEGIN
    IF NEW.quantity_available <= NEW.reorder_level THEN
        INSERT INTO restock_alert (inventory_id, quantity_at_alert)
        SELECT NEW.inventory_id, NEW.quantity_available
         WHERE NOT EXISTS (SELECT 1
                             FROM restock_alert ra
                            WHERE ra.inventory_id = NEW.inventory_id
                              AND NOT ra.resolved);
    ELSE
        UPDATE restock_alert
           SET resolved = TRUE
         WHERE inventory_id = NEW.inventory_id
           AND NOT resolved;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS t4_inventory_low_stock_alert ON inventory_item;
CREATE TRIGGER t4_inventory_low_stock_alert
AFTER INSERT OR UPDATE OF quantity_available ON inventory_item
FOR EACH ROW EXECUTE FUNCTION trg_inventory_low_stock_alert();


CREATE OR REPLACE FUNCTION trg_purchase_increase_stock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
DECLARE
    v_inv_canteen INT;
BEGIN
    SELECT i.canteen_id INTO v_inv_canteen
      FROM inventory_item i
     WHERE i.inventory_id = NEW.inventory_id
       FOR UPDATE;

    IF v_inv_canteen IS DISTINCT FROM NEW.canteen_id THEN
        RAISE EXCEPTION 'Inventory item % does not belong to canteen %', NEW.inventory_id, NEW.canteen_id
            USING ERRCODE = 'MN004';
    END IF;

    UPDATE inventory_item
       SET quantity_available = quantity_available + NEW.quantity
     WHERE inventory_id = NEW.inventory_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS t5_purchase_increase_stock ON purchase;
CREATE TRIGGER t5_purchase_increase_stock
AFTER INSERT ON purchase
FOR EACH ROW EXECUTE FUNCTION trg_purchase_increase_stock();


CREATE OR REPLACE FUNCTION trg_order_status_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO order_audit_log (order_id, old_status, new_status)
        VALUES (NEW.order_id, NULL, NEW.order_status);
    ELSIF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
        INSERT INTO order_audit_log (order_id, old_status, new_status)
        VALUES (NEW.order_id, OLD.order_status, NEW.order_status);
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS t6_order_status_audit ON orders;
CREATE TRIGGER t6_order_status_audit
AFTER INSERT OR UPDATE OF order_status ON orders
FOR EACH ROW EXECUTE FUNCTION trg_order_status_audit();


CREATE OR REPLACE FUNCTION trg_order_status_validate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
BEGIN
    IF NOT (
        (OLD.order_status = 'PLACED'    AND NEW.order_status IN ('CONFIRMED', 'CANCELLED')) OR
        (OLD.order_status = 'CONFIRMED' AND NEW.order_status IN ('PREPARING', 'CANCELLED')) OR
        (OLD.order_status = 'PREPARING' AND NEW.order_status = 'READY') OR
        (OLD.order_status = 'READY'     AND NEW.order_status = 'COMPLETED')
    ) THEN
        RAISE EXCEPTION 'Invalid status change: % -> %', OLD.order_status, NEW.order_status
            USING ERRCODE = 'MN005';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS t7_order_status_validate ON orders;
CREATE TRIGGER t7_order_status_validate
BEFORE UPDATE OF order_status ON orders
FOR EACH ROW
WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
EXECUTE FUNCTION trg_order_status_validate();


CREATE OR REPLACE FUNCTION get_order_total(p_order_id INT)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SET search_path = munch, public
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = p_order_id) THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id USING ERRCODE = 'MN004';
    END IF;

    SELECT COALESCE(SUM(oi.subtotal), 0) INTO v_total
      FROM order_item oi
     WHERE oi.order_id = p_order_id;

    RETURN v_total;
END;
$$;


CREATE OR REPLACE PROCEDURE place_order(
    p_student_id INT,
    p_canteen_id INT,
    p_items JSONB,
    INOUT p_order_id INT DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
DECLARE
    v_line RECORD;
    v_item_id INT;
    v_qty INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM student s WHERE s.student_id = p_student_id) THEN
        RAISE EXCEPTION 'Student % does not exist', p_student_id USING ERRCODE = 'MN004';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM canteen c WHERE c.canteen_id = p_canteen_id) THEN
        RAISE EXCEPTION 'Canteen % does not exist', p_canteen_id USING ERRCODE = 'MN004';
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order must contain at least one item' USING ERRCODE = 'MN004';
    END IF;

    PERFORM 1
       FROM inventory_item i
      WHERE i.inventory_id IN (SELECT rc.inventory_id
                                 FROM recipe rc
                                WHERE rc.item_id IN (SELECT (e.elem->>'item_id')::INT
                                                       FROM jsonb_array_elements(p_items) AS e(elem)))
      ORDER BY i.inventory_id
        FOR UPDATE;

    INSERT INTO orders (student_id, canteen_id)
    VALUES (p_student_id, p_canteen_id)
    RETURNING order_id INTO p_order_id;

    FOR v_line IN
        SELECT e.elem, e.line_no
          FROM jsonb_array_elements(p_items) WITH ORDINALITY AS e(elem, line_no)
         ORDER BY e.line_no
    LOOP
        BEGIN
            v_item_id := (v_line.elem->>'item_id')::INT;
            v_qty := (v_line.elem->>'qty')::INT;

            IF v_item_id IS NULL OR v_qty IS NULL OR v_qty <= 0 THEN
                RAISE EXCEPTION 'Each item needs an item_id and a positive qty' USING ERRCODE = 'MN004';
            END IF;

            INSERT INTO order_item (order_id, line_no, item_id, quantity)
            VALUES (p_order_id, v_line.line_no, v_item_id, v_qty);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Line %: %', v_line.line_no, SQLERRM USING ERRCODE = SQLSTATE;
        END;
    END LOOP;
END;
$$;


CREATE OR REPLACE PROCEDURE process_payment(
    p_order_id INT,
    p_method TEXT,
    INOUT p_payment_id INT DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
DECLARE
    v_status order_status;
    v_total NUMERIC;
    v_method payment_method;
    v_existing payment_status;
BEGIN
    SELECT o.order_status, o.total_amount
      INTO v_status, v_total
      FROM orders o
     WHERE o.order_id = p_order_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id USING ERRCODE = 'MN004';
    END IF;

    IF v_status <> 'PLACED' THEN
        RAISE EXCEPTION 'Order % cannot be paid (status: %)', p_order_id, v_status USING ERRCODE = 'MN003';
    END IF;

    BEGIN
        v_method := upper(p_method)::payment_method;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'Invalid payment method "%"', p_method USING ERRCODE = 'MN003';
    END;

    IF v_total <= 0 THEN
        RAISE EXCEPTION 'Order % has nothing to pay', p_order_id USING ERRCODE = 'MN003';
    END IF;

    SELECT p.payment_status INTO v_existing FROM payment p WHERE p.order_id = p_order_id;

    IF FOUND AND v_existing = 'SUCCESS' THEN
        RAISE EXCEPTION 'Order % is already paid', p_order_id USING ERRCODE = 'MN003';
    END IF;

    INSERT INTO payment (order_id, amount, payment_method, payment_status)
    VALUES (p_order_id, v_total, v_method, 'SUCCESS')
    ON CONFLICT (order_id) DO UPDATE
        SET amount = EXCLUDED.amount,
            payment_method = EXCLUDED.payment_method,
            payment_status = 'SUCCESS',
            payment_time = now()
    RETURNING payment_id INTO p_payment_id;

    UPDATE orders SET order_status = 'CONFIRMED' WHERE order_id = p_order_id;
END;
$$;


CREATE OR REPLACE PROCEDURE cancel_order(p_order_id INT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
DECLARE
    v_status order_status;
BEGIN
    SELECT o.order_status INTO v_status
      FROM orders o
     WHERE o.order_id = p_order_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id USING ERRCODE = 'MN004';
    END IF;

    IF v_status NOT IN ('PLACED', 'CONFIRMED') THEN
        RAISE EXCEPTION 'Order % can no longer be cancelled (status: %)', p_order_id, v_status
            USING ERRCODE = 'MN005';
    END IF;

    UPDATE payment
       SET payment_status = 'REFUNDED'
     WHERE order_id = p_order_id
       AND payment_status = 'SUCCESS';

    UPDATE orders SET order_status = 'CANCELLED' WHERE order_id = p_order_id;
END;
$$;


CREATE OR REPLACE PROCEDURE update_order_status(p_order_id INT, p_status TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = munch, public
AS $$
DECLARE
    v_new order_status;
BEGIN
    BEGIN
        v_new := upper(p_status)::order_status;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'Invalid status "%"', p_status USING ERRCODE = 'MN004';
    END;

    IF v_new = 'CANCELLED' THEN
        CALL cancel_order(p_order_id);
        RETURN;
    END IF;

    UPDATE orders SET order_status = v_new WHERE order_id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id USING ERRCODE = 'MN004';
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION get_low_stock_items(p_canteen_id INT DEFAULT NULL)
RETURNS TABLE (
    inventory_id INT,
    canteen_id INT,
    item_name VARCHAR,
    quantity_available NUMERIC,
    reorder_level NUMERIC,
    unit VARCHAR,
    shortfall NUMERIC
)
LANGUAGE plpgsql
STABLE
SET search_path = munch, public
AS $$
BEGIN
    RETURN QUERY
    SELECT i.inventory_id,
           i.canteen_id,
           i.item_name,
           i.quantity_available,
           i.reorder_level,
           i.unit,
           i.reorder_level - i.quantity_available
      FROM inventory_item i
     WHERE i.quantity_available <= i.reorder_level
       AND (p_canteen_id IS NULL OR i.canteen_id = p_canteen_id)
     ORDER BY i.reorder_level - i.quantity_available DESC, i.item_name;
END;
$$;


CREATE OR REPLACE FUNCTION generate_restock_suggestions(p_canteen_id INT DEFAULT NULL)
RETURNS TABLE (
    inventory_id INT,
    item_name VARCHAR,
    unit VARCHAR,
    current_qty NUMERIC,
    suggested_qty NUMERIC,
    last_supplier_id INT,
    last_supplier_name VARCHAR
)
LANGUAGE plpgsql
STABLE
SET search_path = munch, public
AS $$
DECLARE
    cur CURSOR FOR
        SELECT l.inventory_id, l.item_name, l.unit, l.quantity_available, l.reorder_level
          FROM get_low_stock_items(p_canteen_id) l;
    rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;

        inventory_id := rec.inventory_id;
        item_name := rec.item_name;
        unit := rec.unit;
        current_qty := rec.quantity_available;
        suggested_qty := GREATEST(rec.reorder_level * 2 - rec.quantity_available, 0);

        SELECT s.supplier_id, s.name
          INTO last_supplier_id, last_supplier_name
          FROM purchase p
          JOIN supplier s ON s.supplier_id = p.supplier_id
         WHERE p.inventory_id = rec.inventory_id
         ORDER BY p.purchase_date DESC, p.purchase_id DESC
         LIMIT 1;

        RETURN NEXT;
    END LOOP;
    CLOSE cur;
END;
$$;
