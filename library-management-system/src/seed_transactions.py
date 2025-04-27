"""
Generate and bulk-load borrowing_transactions, reservations,
payments, and notifications.

Prereqs:
  • members.csv, library_items.csv, staff.csv already exist in supabase/seed
  • database schema + triggers already applied
  • .env holds user/password/host/port/dbname
"""

import csv, os, random, datetime as dt
from pathlib import Path
import psycopg2
from dotenv import load_dotenv
from psycopg2 import sql

BASE = Path(__file__).resolve().parents[1]
SEED = BASE / "supabase" / "seed" / "input"

def rand_date(back_start, back_end=0):
    today = dt.date.today()
    days  = random.randint(back_end, back_start)
    return today - dt.timedelta(days=days)

def generate_csvs():
    members = sum(1 for _ in open(SEED/"members.csv")) - 1
    items   = sum(1 for _ in open(SEED/"library_items.csv")) - 1
    staff   = sum(1 for _ in open(SEED/"staff.csv")) - 1

    bor, res, pay, notif = [], [], [], []
    notif_types = ["Due Date Alert","Overdue Alert","Reservation"]

    # borrowings
    for _ in range(40):
        b_date = rand_date(60,1)
        row = {
            "member_id": random.randint(1,members),
            "item_id":   random.randint(1,items),
            "staff_id":  random.randint(1,staff),
            "borrow_date": b_date,
            "due_date":    b_date + dt.timedelta(days=14),
            "return_date": "" if random.random()>0.6 else
                            (b_date + dt.timedelta(days=random.randint(1,30)))
        }
        bor.append(row)

    # reservations
    for _ in range(15):
        r_date = rand_date(15,1)
        res.append({
            "member_id": random.randint(1,members),
            "item_id":   random.randint(1,items),
            "reservation_date": r_date,
            "expiry_date":      r_date + dt.timedelta(days=7)
        })

    # payments
    for _ in range(10):
        pay.append({
            "member_id":  random.randint(1,members),
            "amount_paid": round(random.uniform(1,10),2),
            "payment_date": rand_date(10,0)
        })

    # notifications
    for _ in range(25):
        notif.append({
            "member_id": random.randint(1,members),
            "notification_date": rand_date(7,0),
            "notification_type": random.choice(notif_types)
        })

    def dump(name, rows, cols):
        path = SEED/f"{name}.csv"
        with open(path,"w",newline="") as f:
            writer = csv.DictWriter(f, fieldnames=cols)
            writer.writeheader(); writer.writerows(rows)
        print("📝", path.name)

    dump("borrowing_transactions", bor,
         ["member_id","item_id","staff_id","borrow_date","due_date","return_date"])
    dump("reservations",           res,
         ["member_id","item_id","reservation_date","expiry_date"])
    dump("payments",               pay,
         ["member_id","amount_paid","payment_date"])
    dump("notifications",          notif,
         ["member_id","notification_date","notification_type"])

def copy_csv(cur, table, cols):
    path = SEED/f"{table}.csv"
    with open(path,"r") as f:
        cur.copy_expert(
            sql.SQL("COPY {} ({}) FROM STDIN WITH CSV HEADER").format(
                sql.Identifier(table),
                sql.SQL(', ').join(map(sql.Identifier, cols))
            ), f)
    print("➡️  loaded", table)

def load_into_db():
    load_dotenv(BASE/".env")
    conn = psycopg2.connect(
        user=os.getenv("user"), password=os.getenv("password"),
        host=os.getenv("host"), port=os.getenv("port"), dbname=os.getenv("dbname")
    )
    with conn, conn.cursor() as cur:
        copy_csv(cur,"borrowing_transactions",
                 ["member_id","item_id","staff_id","borrow_date",
                  "due_date","return_date"])
        copy_csv(cur,"reservations",
                 ["member_id","item_id","reservation_date","expiry_date"])
        copy_csv(cur,"payments",
                 ["member_id","amount_paid","payment_date"])
        copy_csv(cur,"notifications",
                 ["member_id","notification_date","notification_type"])

if __name__ == "__main__":
    generate_csvs()   # writes the four CSVs
    load_into_db()    # bulk-loads them
    print("✅  Transactions seeded")
