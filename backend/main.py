import os
from contextlib import asynccontextmanager
from datetime import date
from decimal import Decimal
from typing import Literal

from fastapi import FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from psycopg.types.json import Jsonb

from db import close_pool, connection, open_pool


@asynccontextmanager
async def lifespan(_: FastAPI):
    open_pool()
    try:
        yield
    finally:
        close_pool()


app = FastAPI(title="Munch API", version="1.0.0", lifespan=lifespan)

cors_origins = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ORIGINS",
        "http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000",
    ).split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
    allow_headers=["*"],
)


class OrderLine(BaseModel):
    item_id: int = Field(gt=0)
    qty: int = Field(gt=0)


class OrderCreate(BaseModel):
    student_id: int = Field(gt=0)
    canteen_id: int = Field(gt=0)
    items: list[OrderLine] = Field(min_length=1)


class PaymentCreate(BaseModel):
    order_id: int = Field(gt=0)
    method: Literal["UPI", "CARD", "CASH", "WALLET"]


class OrderStatusUpdate(BaseModel):
    status: Literal["PLACED", "CONFIRMED", "PREPARING", "READY", "COMPLETED", "CANCELLED"]


class ReviewCreate(BaseModel):
    student_id: int = Field(gt=0)
    item_id: int = Field(gt=0)
    rating: int = Field(ge=1, le=5)
    comment: str | None = None


class PurchaseCreate(BaseModel):
    supplier_id: int = Field(gt=0)
    inventory_id: int = Field(gt=0)
    canteen_id: int = Field(gt=0)
    quantity: Decimal = Field(gt=0)
    cost: Decimal = Field(ge=0)


@app.get("/health")
def health():
    with connection() as conn:
        row = conn.execute(
            "SELECT now() AS server_time, current_schema() AS schema"
        ).fetchone()
    return {"status": "ok", **row}


@app.get("/canteens")
def list_canteens():
    with connection() as conn:
        rows = conn.execute(
            """
            SELECT canteen_id, name, location, opening_time, closing_time
            FROM munch.canteen
            ORDER BY name
            """
        ).fetchall()
    return rows


@app.get("/menu")
def list_menu(canteen_id: int = Query(gt=0)):
    with connection() as conn:
        rows = conn.execute(
            """
            SELECT m.item_id,
                   m.item_name,
                   m.description,
                   m.price,
                   c.category_name,
                   m.availability_status,
                   ROUND(AVG(r.rating)::numeric, 2) AS avg_rating
            FROM munch.menu_item AS m
            JOIN munch.category AS c ON c.category_id = m.category_id
            LEFT JOIN munch.review AS r ON r.item_id = m.item_id
            WHERE m.canteen_id = %s
            GROUP BY m.item_id, c.category_name
            ORDER BY c.category_name, m.item_name
            """,
            (canteen_id,),
        ).fetchall()
    return rows


@app.post("/orders", status_code=status.HTTP_201_CREATED)
def place_order(payload: OrderCreate):
    items = [{"item_id": line.item_id, "qty": line.qty} for line in payload.items]
    with connection() as conn:
        result = conn.execute(
            "CALL munch.place_order(%s, %s, %s, NULL)",
            (payload.student_id, payload.canteen_id, Jsonb(items)),
        ).fetchone()
        order_id = result["p_order_id"] if result else None
        if order_id is None:
            raise HTTPException(status_code=500, detail="The order was created without an ID")
        order = conn.execute(
            "SELECT order_id, total_amount, order_status AS status "
            "FROM munch.orders WHERE order_id = %s",
            (order_id,),
        ).fetchone()
    return order


@app.get("/orders/{order_id}")
def get_order(order_id: int):
    with connection() as conn:
        order = conn.execute(
            """
            SELECT order_id, student_id, canteen_id, order_date, order_time,
                   order_status AS status, total_amount
            FROM munch.orders
            WHERE order_id = %s
            """,
            (order_id,),
        ).fetchone()
        if order is None:
            raise HTTPException(status_code=404, detail="Order not found")
        items = conn.execute(
            """
            SELECT m.item_name, oi.quantity, oi.price_at_order, oi.subtotal
            FROM munch.order_item AS oi
            JOIN munch.menu_item AS m ON m.item_id = oi.item_id
            WHERE oi.order_id = %s
            ORDER BY oi.line_no
            """,
            (order_id,),
        ).fetchall()
        payment = conn.execute(
            """
            SELECT payment_id, amount, payment_method AS method,
                   payment_status AS status, payment_time
            FROM munch.payment
            WHERE order_id = %s
            """,
            (order_id,),
        ).fetchone()
    return {**order, "items": items, "payment": payment}


@app.get("/students/{student_id}/orders")
def list_student_orders(student_id: int):
    with connection() as conn:
        student = conn.execute(
            "SELECT 1 FROM munch.student WHERE student_id = %s", (student_id,)
        ).fetchone()
        if student is None:
            raise HTTPException(status_code=404, detail="Student not found")
        rows = conn.execute(
            """
            SELECT o.order_id, o.order_date, o.order_time, o.order_status AS status,
                   o.total_amount, oi.line_no, oi.quantity, oi.price_at_order,
                   oi.subtotal, m.item_name,
                   p.payment_id, p.payment_method AS payment_method,
                   p.payment_status AS payment_status
            FROM munch.orders AS o
            LEFT JOIN munch.order_item AS oi ON oi.order_id = o.order_id
            LEFT JOIN munch.menu_item AS m ON m.item_id = oi.item_id
            LEFT JOIN munch.payment AS p ON p.order_id = o.order_id
            WHERE o.student_id = %s
            ORDER BY o.order_date DESC, o.order_time DESC, o.order_id DESC, oi.line_no
            """,
            (student_id,),
        ).fetchall()

    orders: dict[int, dict] = {}
    for row in rows:
        order_id = row["order_id"]
        if order_id not in orders:
            orders[order_id] = {
                "order_id": order_id,
                "order_date": row["order_date"],
                "order_time": row["order_time"],
                "status": row["status"],
                "total_amount": row["total_amount"],
                "items": [],
                "payment": None,
            }
            if row["payment_id"] is not None:
                orders[order_id]["payment"] = {
                    "payment_id": row["payment_id"],
                    "method": row["payment_method"],
                    "status": row["payment_status"],
                }
        if row["line_no"] is not None:
            orders[order_id]["items"].append(
                {
                    "item_name": row["item_name"],
                    "quantity": row["quantity"],
                    "price_at_order": row["price_at_order"],
                    "subtotal": row["subtotal"],
                }
            )
    return list(orders.values())


@app.post("/payments", status_code=status.HTTP_201_CREATED)
def process_payment(payload: PaymentCreate):
    with connection() as conn:
        result = conn.execute(
            "CALL munch.process_payment(%s, %s, NULL)",
            (payload.order_id, payload.method),
        ).fetchone()
        payment_id = result["p_payment_id"] if result else None
        payment = conn.execute(
            "SELECT payment_id, payment_status AS status FROM munch.payment "
            "WHERE payment_id = %s",
            (payment_id,),
        ).fetchone()
    return payment


@app.patch("/orders/{order_id}/status")
def update_order_status(order_id: int, payload: OrderStatusUpdate):
    with connection() as conn:
        conn.execute(
            "CALL munch.update_order_status(%s, %s)", (order_id, payload.status)
        )
        order = conn.execute(
            "SELECT order_id, order_status AS status FROM munch.orders WHERE order_id = %s",
            (order_id,),
        ).fetchone()
    return order


@app.post("/orders/{order_id}/cancel")
def cancel_order(order_id: int):
    with connection() as conn:
        conn.execute("CALL munch.cancel_order(%s)", (order_id,))
        order = conn.execute(
            "SELECT order_id, order_status AS status FROM munch.orders WHERE order_id = %s",
            (order_id,),
        ).fetchone()
    return order


@app.post("/reviews", status_code=status.HTTP_201_CREATED)
def create_review(payload: ReviewCreate):
    with connection() as conn:
        row = conn.execute(
            """
            INSERT INTO munch.review (student_id, item_id, rating, comment)
            VALUES (%s, %s, %s, %s)
            RETURNING review_id
            """,
            (payload.student_id, payload.item_id, payload.rating, payload.comment),
        ).fetchone()
    return row


@app.get("/admin/inventory/low-stock")
def low_stock(canteen_id: int | None = Query(default=None, gt=0)):
    with connection() as conn:
        rows = conn.execute(
            "SELECT * FROM munch.get_low_stock_items(%s)", (canteen_id,)
        ).fetchall()
    return rows


@app.get("/admin/restock-suggestions")
def restock_suggestions(canteen_id: int | None = Query(default=None, gt=0)):
    with connection() as conn:
        rows = conn.execute(
            "SELECT * FROM munch.generate_restock_suggestions(%s)", (canteen_id,)
        ).fetchall()
    return rows


@app.post("/admin/purchases", status_code=status.HTTP_201_CREATED)
def create_purchase(payload: PurchaseCreate):
    with connection() as conn:
        row = conn.execute(
            """
            INSERT INTO munch.purchase
                (supplier_id, inventory_id, canteen_id, quantity, cost)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING purchase_id
            """,
            (
                payload.supplier_id,
                payload.inventory_id,
                payload.canteen_id,
                payload.quantity,
                payload.cost,
            ),
        ).fetchone()
    return row


@app.get("/admin/reports/sales")
def daily_sales(start_date: date | None = None, end_date: date | None = None):
    if start_date and end_date and start_date > end_date:
        raise HTTPException(status_code=422, detail="start_date must be on or before end_date")
    with connection() as conn:
        rows = conn.execute(
            """
            SELECT o.order_date AS sales_date,
                   c.canteen_id,
                   c.name AS canteen_name,
                   COUNT(DISTINCT o.order_id) AS orders_count,
                   SUM(o.total_amount) AS total_sales
            FROM munch.orders AS o
            JOIN munch.canteen AS c ON c.canteen_id = o.canteen_id
            JOIN munch.payment AS p ON p.order_id = o.order_id
            WHERE p.payment_status = 'SUCCESS'
              AND o.order_status <> 'CANCELLED'
              AND (%s::date IS NULL OR o.order_date >= %s)
              AND (%s::date IS NULL OR o.order_date <= %s)
            GROUP BY o.order_date, c.canteen_id, c.name
            ORDER BY o.order_date, c.name
            """,
            (start_date, start_date, end_date, end_date),
        ).fetchall()
    return rows


@app.get("/admin/reports/top-items")
def top_items(limit: int = Query(default=10, ge=1, le=100)):
    with connection() as conn:
        rows = conn.execute(
            """
            SELECT ranked.item_id,
                   ranked.item_name,
                   ranked.category_name,
                   ranked.quantity_ordered,
                   ranked.revenue,
                   ranked.item_rank
            FROM (
                SELECT m.item_id,
                       m.item_name,
                       c.category_name,
                       SUM(oi.quantity) AS quantity_ordered,
                       SUM(oi.subtotal) AS revenue,
                       RANK() OVER (ORDER BY SUM(oi.quantity) DESC) AS item_rank
                FROM munch.order_item AS oi
                JOIN munch.orders AS o ON o.order_id = oi.order_id
                JOIN munch.menu_item AS m ON m.item_id = oi.item_id
                JOIN munch.category AS c ON c.category_id = m.category_id
                WHERE o.order_status <> 'CANCELLED'
                GROUP BY m.item_id, m.item_name, c.category_name
            ) AS ranked
            ORDER BY ranked.item_rank, ranked.item_name
            LIMIT %s
            """,
            (limit,),
        ).fetchall()
    return rows


@app.get("/admin/audit-log/{order_id}")
def order_audit_log(order_id: int):
    with connection() as conn:
        exists = conn.execute(
            "SELECT 1 FROM munch.orders WHERE order_id = %s", (order_id,)
        ).fetchone()
        if exists is None:
            raise HTTPException(status_code=404, detail="Order not found")
        rows = conn.execute(
            """
            SELECT order_id, old_status, new_status, changed_at
            FROM munch.order_audit_log
            WHERE order_id = %s
            ORDER BY changed_at, log_id
            """,
            (order_id,),
        ).fetchall()
    return rows
