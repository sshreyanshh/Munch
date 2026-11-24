DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'student_role') THEN
        CREATE ROLE student_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'staff_role') THEN
        CREATE ROLE staff_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_role') THEN
        CREATE ROLE admin_role NOLOGIN;
    END IF;
END;
$$;

GRANT USAGE ON SCHEMA munch TO student_role, staff_role, admin_role;

GRANT SELECT ON munch.canteen, munch.category, munch.menu_item TO student_role;
GRANT INSERT ON munch.review TO student_role;
GRANT USAGE, SELECT ON SEQUENCE munch.review_review_id_seq TO student_role;
GRANT EXECUTE ON PROCEDURE munch.place_order(INT, INT, JSONB, INT) TO student_role;
GRANT EXECUTE ON PROCEDURE munch.process_payment(INT, TEXT, INT) TO student_role;
GRANT EXECUTE ON PROCEDURE munch.cancel_order(INT) TO student_role;

GRANT SELECT ON munch.inventory_item, munch.orders TO staff_role;
GRANT EXECUTE ON PROCEDURE munch.update_order_status(INT, TEXT) TO staff_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA munch TO admin_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA munch TO admin_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA munch TO admin_role;
GRANT EXECUTE ON PROCEDURE munch.place_order(INT, INT, JSONB, INT) TO admin_role;
GRANT EXECUTE ON PROCEDURE munch.process_payment(INT, TEXT, INT) TO admin_role;
GRANT EXECUTE ON PROCEDURE munch.cancel_order(INT) TO admin_role;
GRANT EXECUTE ON PROCEDURE munch.update_order_status(INT, TEXT) TO admin_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA munch
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO admin_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA munch
    GRANT USAGE, SELECT ON SEQUENCES TO admin_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA munch
    GRANT EXECUTE ON FUNCTIONS TO admin_role;

