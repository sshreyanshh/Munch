from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db import pool

app = FastAPI(title="Munch API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    with pool.connection() as conn:
        row = conn.execute("SELECT now() AS server_time, current_schema() AS schema").fetchone()
    return {"status": "ok", **row}