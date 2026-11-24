SET search_path TO munch, public;

DROP TABLE IF EXISTS order_audit_log CASCADE;
DROP TABLE IF EXISTS restock_alert CASCADE;
DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS purchase CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS order_item CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS recipe CASCADE;
DROP TABLE IF EXISTS staff CASCADE;
DROP TABLE IF EXISTS inventory_item CASCADE;
DROP TABLE IF EXISTS menu_item CASCADE;
DROP TABLE IF EXISTS supplier CASCADE;
DROP TABLE IF EXISTS category CASCADE;
DROP TABLE IF EXISTS canteen CASCADE;
DROP TABLE IF EXISTS student CASCADE;

DROP TYPE IF EXISTS order_status CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS payment_method CASCADE;

CREATE TYPE order_status AS ENUM ('PLACED','CONFIRMED','PREPARING','READY','COMPLETED','CANCELLED');
CREATE TYPE payment_status AS ENUM ('PENDING','SUCCESS','FAILED','REFUNDED');
CREATE TYPE payment_method AS ENUM ('UPI','CARD','CASH','WALLET');

CREATE TABLE student (
    student_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(15),
    department VARCHAR(50),
    year SMALLINT CHECK (year BETWEEN 1 AND 5)
);

CREATE TABLE canteen (
    canteen_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(150) NOT NULL,
    contact VARCHAR(15),
    opening_time TIME NOT NULL,
    closing_time TIME NOT NULL,
    CONSTRAINT chk_canteen_hours CHECK (closing_time > opening_time)
);

CREATE TABLE category (
    category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE supplier (
    supplier_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15),
    email VARCHAR(120) UNIQUE,
    address VARCHAR(200)
);

CREATE TABLE menu_item (
    item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id INT NOT NULL REFERENCES category(category_id) ON DELETE RESTRICT,
    canteen_id INT NOT NULL REFERENCES canteen(canteen_id) ON DELETE RESTRICT,
    item_name VARCHAR(100) NOT NULL,
    description TEXT,
    price NUMERIC(8,2) NOT NULL CHECK (price > 0),
    availability_status BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_menu_item_per_canteen UNIQUE (canteen_id, item_name)
);

CREATE TABLE inventory_item (
    inventory_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    canteen_id INT NOT NULL REFERENCES canteen(canteen_id) ON DELETE RESTRICT,
    item_name VARCHAR(100) NOT NULL,
    quantity_available NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (quantity_available >= 0),
    unit VARCHAR(20) NOT NULL,
    reorder_level NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
    CONSTRAINT uq_inventory_per_canteen UNIQUE (canteen_id, item_name)
);

CREATE TABLE staff (
    staff_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    canteen_id INT NOT NULL REFERENCES canteen(canteen_id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL,
    phone VARCHAR(15)
);

CREATE TABLE recipe (
    item_id INT NOT NULL REFERENCES menu_item(item_id) ON DELETE CASCADE,
    inventory_id INT NOT NULL REFERENCES inventory_item(inventory_id) ON DELETE RESTRICT,
    qty_used NUMERIC(10,3) NOT NULL CHECK (qty_used > 0),
    PRIMARY KEY (item_id, inventory_id)
);

CREATE TABLE orders (
    order_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id INT NOT NULL REFERENCES student(student_id) ON DELETE RESTRICT,
    canteen_id INT NOT NULL REFERENCES canteen(canteen_id) ON DELETE RESTRICT,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    order_time TIME NOT NULL DEFAULT CURRENT_TIME,
    order_status order_status NOT NULL DEFAULT 'PLACED',
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0)
);

CREATE TABLE order_item (
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    line_no INT NOT NULL CHECK (line_no > 0),
    item_id INT NOT NULL REFERENCES menu_item(item_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    price_at_order NUMERIC(8,2) NOT NULL CHECK (price_at_order > 0),
    subtotal NUMERIC(10,2) GENERATED ALWAYS AS (quantity * price_at_order) STORED,
    PRIMARY KEY (order_id, line_no)
);

CREATE TABLE payment (
    payment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT NOT NULL UNIQUE REFERENCES orders(order_id) ON DELETE RESTRICT,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    payment_method payment_method NOT NULL,
    payment_status payment_status NOT NULL DEFAULT 'PENDING',
    payment_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE purchase (
    purchase_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id INT NOT NULL REFERENCES supplier(supplier_id) ON DELETE RESTRICT,
    inventory_id INT NOT NULL REFERENCES inventory_item(inventory_id) ON DELETE RESTRICT,
    canteen_id INT NOT NULL REFERENCES canteen(canteen_id) ON DELETE RESTRICT,
    quantity NUMERIC(10,2) NOT NULL CHECK (quantity > 0),
    purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
    cost NUMERIC(10,2) NOT NULL CHECK (cost >= 0)
);

CREATE TABLE review (
    review_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id INT NOT NULL REFERENCES student(student_id) ON DELETE CASCADE,
    item_id INT NOT NULL REFERENCES menu_item(item_id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    review_date DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT uq_one_review_per_student_item UNIQUE (student_id, item_id)
);

CREATE TABLE restock_alert (
    alert_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    inventory_id INT NOT NULL REFERENCES inventory_item(inventory_id) ON DELETE CASCADE,
    quantity_at_alert NUMERIC(10,2) NOT NULL,
    alert_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE order_audit_log (
    log_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    old_status order_status,
    new_status order_status NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);