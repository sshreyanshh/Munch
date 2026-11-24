# munch

campus canteen ordering system for jiit noida. place orders, track them live, manage kitchen queue, monitor inventory.
---

## what it does

students browse a live menu, add items to cart, pay, and track their order through kitchen stages in real time. the admin side handles the kitchen queue, inventory levels, restock suggestions, and daily sales. all core logic lives in the database — triggers handle stock deduction, price snapshots, audit trails, and state machine validation.

## stack

| layer | tech |
|---|---|
| database | postgresql 17 (supabase) |
| backend | fastapi + psycopg v3, python 3.14 |
| frontend | vanilla js + html/css, jetbrains mono |


## running it

```bash
# backend
cd backend
uv run uvicorn main:app --reload --port 8000

# frontend (separate terminal)
cd frontend
python3 -m http.server 5173
```

open `http://localhost:5173`. needs `.env` in the project root with `DATABASE_URL`.

## database setup

```bash
cd db
python3 migrate.py      # runs migrations 00–06 in order
```

> this wipes and rebuilds the full schema, then seeds all 84 menu items and baseline data.

## structure

```
db/
  01_schema.sql          15 tables, domain types
  02_triggers_functions  8 triggers + stored procedures
  04_seed.sql            84 menu items, inventory, 2 baseline orders
  05_views_indexes.sql   views + 8 indexes
  06_queries.sql         17 analytical queries
  migrate.py             migration runner
backend/                 fastapi routes
frontend/                single-page app (menu, cart, tracker, admin)
docs/report.md           full project report (normalization, indexing, etc.)
```
