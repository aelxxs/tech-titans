"""
Populate Supabase/Postgres with sample data.
• Reads env vars: user, password, host, port, dbname
• Requires the CSVs we created earlier in supabase/seed/
"""

import csv, os, psycopg2
from pathlib import Path
from dotenv import load_dotenv
from psycopg2 import sql

BASE_DIR = Path(__file__).resolve().parents[1]
SEED_DIR = BASE_DIR / "supabase" / "seed" / "input"
LOOKUP_SQL = SEED_DIR / "01_sample_data.sql"

# Map CSV filenames to the columns used in COPY
CSV_MAP = {
    "members.csv":       ("members",
                          ["name","contact_info","membership_type_id",
                           "account_status"]),
}

def get_conn():
    load_dotenv(BASE_DIR / ".env")
    return psycopg2.connect(
        user=os.getenv("user"),
        password=os.getenv("password"),
        host=os.getenv("host"),
        port=os.getenv("port"),
        dbname=os.getenv("dbname")
    )

def truncate_tables(cur):
    # Truncate in FK-safe order
    tables = ["notifications","payments","reservations",
              "borrowing_transactions","books","digital_media",
              "magazines","library_items","members","staff",
              "membership_types"]
    for t in tables:
        cur.execute(sql.SQL("TRUNCATE {} CASCADE").format(sql.Identifier(t)))

def copy_csv(cur, table, cols, path):
    with path.open("r", encoding="utf-8") as f:
        cur.copy_expert(
            sql.SQL("COPY {} ({}) FROM STDIN WITH CSV HEADER").format(
                sql.Identifier(table),
                sql.SQL(", ").join(map(sql.Identifier, cols))
            ),
            f
        )
    print(f"COPIED {path.name} → {table}")

def load_members(cur):
    file = SEED_DIR / "members.csv"
    table, cols = CSV_MAP[file.name]
    copy_csv(cur, table, cols, file)

def load_items_with_subtypes(cur):
    """Insert library_items row first, grab item_id, then subtype row."""
    # ---- BOOKS ----
    with (SEED_DIR / "books.csv").open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            cur.execute(
                """INSERT INTO library_items(title,item_type,availability_status)
                   VALUES(%s,'Book','Available') RETURNING item_id""",
                (f"Book Title {row['isbn'][-4:]}",)  # simple derived title
            )
            item_id = cur.fetchone()[0]
            cur.execute(
                """INSERT INTO books(book_id,isbn,author,genre,publication_year)
                   VALUES(%s,%s,%s,%s,%s)""",
                (item_id, row["isbn"], row["author"],
                 row["genre"], row["publication_year"])
            )

    # ---- DIGITAL MEDIA ----
    with (SEED_DIR / "digital_media.csv").open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            cur.execute(
                """INSERT INTO library_items(title,item_type,availability_status)
                   VALUES(%s,'Digital Media','Available') RETURNING item_id""",
                (row["creator"] + " Production",)
            )
            item_id = cur.fetchone()[0]
            cur.execute(
                """INSERT INTO digital_media(media_id,creator,format)
                   VALUES(%s,%s,%s)""",
                (item_id, row["creator"], row["format"])
            )

    # ---- MAGAZINES ----
    with (SEED_DIR / "magazines.csv").open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            cur.execute(
                """INSERT INTO library_items(title,item_type,availability_status)
                   VALUES(%s,'Magazine','Available') RETURNING item_id""",
                (f"Magazine Issue {row['issue_number']}",)
            )
            item_id = cur.fetchone()[0]
            cur.execute(
                """INSERT INTO magazines(magazine_id,issue_number,publication_date)
                   VALUES(%s,%s,%s)""",
                (item_id, row["issue_number"], row["publication_date"])
            )

def main():
    with get_conn() as conn, conn.cursor() as cur:
        truncate_tables(cur)
        # fixed lookup & staff rows
        cur.execute(LOOKUP_SQL.read_text())

        load_members(cur)
        load_items_with_subtypes(cur)

        conn.commit()
        print("✅  Sample data populated")

if __name__ == "__main__":
    main()
