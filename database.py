import sqlite3
from datetime import datetime

DB_NAME = "calls.db"


def initialize_database():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS calls(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caller_name TEXT NOT NULL,
        reason TEXT NOT NULL,
        call_time TEXT NOT NULL
    )
    """)

    conn.commit()
    conn.close()


def save_call(name, reason):
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
    INSERT INTO calls(caller_name, reason, call_time)
    VALUES (?, ?, ?)
    """, (
        name,
        reason,
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))

    conn.commit()
    conn.close()


def get_calls():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
    SELECT * FROM calls
    ORDER BY id DESC
    """)

    rows = cursor.fetchall()

    conn.close()

    return rows


initialize_database()