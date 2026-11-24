#!/usr/bin/env python3
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

project_root = Path(__file__).resolve().parent.parent
load_dotenv(project_root / ".env")

database_url = os.getenv("DATABASE_URL")
if not database_url:
    sys.exit("error: DATABASE_URL not set in .env")

try:
    import psycopg
except ImportError:
    sys.exit("error: psycopg not installed")

sql_files = [
    "00_init.sql",
    "01_schema.sql",
    "02_triggers_functions.sql",
    "03_security.sql",
    "04_seed.sql",
    "05_views_indexes.sql",
    "06_queries.sql",
]

def main():
    db_dir = Path(__file__).resolve().parent
    try:
        with psycopg.connect(database_url, autocommit=True) as conn:
            with conn.cursor() as cur:
                for name in sql_files:
                    path = db_dir / name
                    if not path.exists():
                        continue
                    cur.execute(path.read_text(encoding="utf-8"))
                    print(f"applied {name}")
        print("database ready.")
    except Exception as e:
        sys.exit(f"error: {e}")

if __name__ == "__main__":
    main()
