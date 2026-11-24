# Munch

Campus canteen ordering system for JIIT Noida. Place orders, track them live, manage the kitchen queue, and monitor inventory.
---

## What It Does

Students browse a live menu, add items to the cart, pay, and track their orders through kitchen stages in real time. The admin side handles the kitchen queue, inventory levels, restock suggestions, and daily sales. All core logic lives in the database — triggers handle stock deduction, price snapshots, audit trails, and state machine validation.

## Stack

| Layer | Tech |
|---|---|
| Database | PostgreSQL 17 (Supabase) |
| Backend | FastAPI + psycopg v3, Python 3.14 |
| Frontend | Vanilla JS + HTML/CSS, JetBrains Mono |


## Running It

```bash
# Backend
cd backend
uv run uvicorn main:app --reload --port 8000

# Frontend (separate terminal)
cd frontend
python3 -m http.server 5173
```

Open `http://localhost:5173`. A `.env` file in the project root with `DATABASE_URL` is required.

## Database Setup

```bash
cd db
python3 migrate.py      # runs migrations 00–06 in order
```

> This wipes and rebuilds the full schema, then seeds all 84 menu items and baseline data.

## Structure

```
db/
  01_schema.sql          15 tables, domain types
  02_triggers_functions  8 triggers + stored procedures
  04_seed.sql            84 menu items, inventory, 2 baseline orders
  05_views_indexes.sql   views + 8 indexes
  06_queries.sql         17 analytical queries
  migrate.py             Migration runner
backend/                 FastAPI routes
frontend/                Single-page app (menu, cart, tracker, admin)
docs/report.md           Full project report (normalization, indexing, etc.)
```
