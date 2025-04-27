import os, pathlib, pandas as pd, sqlalchemy
from dotenv import load_dotenv

load_dotenv()
OUT_DIR = pathlib.Path("supabase/seed/output")
OUT_DIR.mkdir(parents=True, exist_ok=True)

engine = sqlalchemy.create_engine(
    f"postgresql+psycopg2://{os.getenv('user')}:{os.getenv('password')}"
    f"@{os.getenv('host')}:{os.getenv('port')}/{os.getenv('dbname')}"
)

tables = [
    "membership_types","staff","members","library_items","books",
    "digital_media","magazines","borrowing_transactions",
    "reservations","payments","notifications"
]

summary = []

with engine.connect() as conn:
    for tbl in tables:
        # preview
        df = pd.read_sql(f"SELECT * FROM {tbl} LIMIT 10", conn)
        df.to_csv(OUT_DIR / f"{tbl}_preview.csv", index=False)

        # row count
        cnt = conn.execute(
            sqlalchemy.text(f"SELECT COUNT(*) FROM {tbl}")
        ).scalar_one()
        summary.append({"table": tbl, "rows": cnt})

pd.DataFrame(summary).to_csv(OUT_DIR / "row_counts.csv", index=False)
print("✅  Previews & counts written to", OUT_DIR)
