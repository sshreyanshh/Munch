import os
from dotenv import load_dotenv
from psycopg_pool import ConnectionPool
from psycopg.rows import dict_row

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

pool = ConnectionPool(
    os.environ["DATABASE_URL"],
    min_size=1,
    max_size=5,
    kwargs={
        "row_factory": dict_row,                 # rows come back as dicts, easy JSON
        "options": "-c search_path=munch,public" # use your own schema
    },
    open=True,
)