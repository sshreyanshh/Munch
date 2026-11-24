import os
from contextlib import contextmanager
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from fastapi import HTTPException
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool


PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

DATABASE_URL = os.getenv("DATABASE_URL")

pool = ConnectionPool(
    conninfo=DATABASE_URL or "",
    min_size=1,
    max_size=10,
    kwargs={
        "row_factory": dict_row,
        "options": "-c search_path=munch,public",
    },
    open=False,
)


def open_pool() -> None:
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL is required to start the Munch API")
    pool.open(wait=True, timeout=10)


def close_pool() -> None:
    pool.close()


def _database_http_error(error: psycopg.Error) -> HTTPException:
    sqlstate = error.sqlstate or ""
    message = str(error).splitlines()[0].strip()

    if sqlstate.startswith("MN"):
        status_code = 404 if sqlstate == "MN004" and any(
            phrase in message.lower()
            for phrase in ("does not exist", "not found")
        ) else 400
        return HTTPException(status_code=status_code, detail=message)
    if sqlstate == "23505":
        return HTTPException(status_code=409, detail="That record already exists")
    if sqlstate == "23503":
        return HTTPException(status_code=404, detail="A referenced record was not found")
    if sqlstate in {"23514", "23502", "22P02", "22003", "22007"}:
        return HTTPException(status_code=400, detail="The supplied data is invalid")
    if isinstance(error, (psycopg.OperationalError, psycopg.InterfaceError)):
        return HTTPException(status_code=503, detail="The database is temporarily unavailable")
    return HTTPException(status_code=500, detail="The database operation failed")


@contextmanager
def connection():
    try:
        with pool.connection() as conn:
            yield conn
    except psycopg.Error as error:
        raise _database_http_error(error) from error
