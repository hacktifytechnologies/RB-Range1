#!/usr/bin/env python3
"""
Database initialisation for PUL Employee Portal (M1)
Run once during setup — idempotent.
"""
import sqlite3
import hashlib
import os

DB_PATH = '/opt/pul-portal/data/users.db'

def hash_pw(p: str) -> str:
    return hashlib.sha256(p.encode()).hexdigest()

os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
conn = sqlite3.connect(DB_PATH)
cur  = conn.cursor()

cur.executescript("""
CREATE TABLE IF NOT EXISTS users (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    name     TEXT    NOT NULL,
    email    TEXT    UNIQUE NOT NULL,
    password TEXT    NOT NULL,
    role     TEXT    NOT NULL DEFAULT 'analyst',
    dept     TEXT    NOT NULL DEFAULT 'Operations'
);

CREATE TABLE IF NOT EXISTS reset_tokens (
    token TEXT PRIMARY KEY,
    email TEXT NOT NULL
);
""")

# Seed employee accounts
users = [
    ('Arun Sharma',    'admin@prabalurja.in',         hash_pw('PUL@Admin!2024'),  'admin',   'IT Infrastructure'),
    ('Priya Nair',     'it.admin@prabalurja.in',      hash_pw('ITA@Secure#99'),   'analyst', 'IT Operations'),
    ('Rajiv Menon',    'soc.analyst@prabalurja.in',   hash_pw('SOC@Prabal!77'),   'analyst', 'Security Operations'),
    ('Deepa Iyer',     'grid.ops@prabalurja.in',      hash_pw('Grid@Ops2024'),    'analyst', 'Grid Operations'),
    ('Sanjay Kulkarni','finance@prabalurja.in',        hash_pw('Fin@PUL$2024'),    'analyst', 'Finance'),
]

for name, email, pw, role, dept in users:
    cur.execute("""
        INSERT OR IGNORE INTO users (name, email, password, role, dept)
        VALUES (?, ?, ?, ?, ?)
    """, (name, email, pw, role, dept))

conn.commit()
conn.close()
print("[+] Database initialised successfully.")
