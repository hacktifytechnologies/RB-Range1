#!/usr/bin/env python3
"""
Prabal Urja Limited — Employee Self-Service Portal
M1 Challenge: HTTP Host Header Injection in Password Reset
Range: RNG-IT-01 | OPERATION GRIDFALL
"""

from flask import (
    Flask, request, render_template, redirect,
    url_for, session, flash, g
)
import sqlite3
import hashlib
import secrets
import os
import logging
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'pul-static-secret-rngit01-2024'

DB_PATH   = '/opt/pul-portal/data/users.db'
LOG_PATH  = '/var/log/pul-portal/reset_requests.log'

logging.basicConfig(
    filename='/var/log/pul-portal/app.log',
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)

# ── DB helpers ────────────────────────────────────────────────────────────────

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def hash_pw(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

# ── Routes ────────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email    = request.form.get('email', '').strip()
        password = request.form.get('password', '')
        conn     = get_db()
        user     = conn.execute(
            'SELECT * FROM users WHERE email = ? AND password = ?',
            (email, hash_pw(password))
        ).fetchone()
        conn.close()
        if user:
            session['user'] = dict(user)
            logging.info(f"Successful login: {email} from {request.remote_addr}")
            return redirect(url_for('dashboard'))
        logging.warning(f"Failed login attempt for {email} from {request.remote_addr}")
        flash('Invalid employee credentials. Please try again.')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/forgot-password', methods=['GET', 'POST'])
def forgot_password():
    message = None
    success = False
    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        conn  = get_db()
        user  = conn.execute(
            'SELECT * FROM users WHERE email = ?', (email,)
        ).fetchone()
        conn.close()
        if user:
            token = secrets.token_urlsafe(48)
            # Store token in DB
            conn = get_db()
            conn.execute(
                'INSERT OR REPLACE INTO reset_tokens (token, email) VALUES (?, ?)',
                (token, email)
            )
            conn.commit()
            conn.close()

            # ── VULNERABILITY: Host header is trusted without validation ──────
            host      = request.headers.get('Host', request.host)
            reset_url = f"http://{host}/reset-password?token={token}"
            # ─────────────────────────────────────────────────────────────────

            # Simulate dispatching reset email — logs the constructed URL
            os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
            with open(LOG_PATH, 'a') as f:
                f.write(f"[{datetime.now().isoformat()}] RESET REQUEST\n")
                f.write(f"  Recipient : {email}\n")
                f.write(f"  Reset URL : {reset_url}\n")
                f.write(f"  Source IP : {request.remote_addr}\n")
                f.write("-" * 60 + "\n")

            logging.info(f"Password reset requested for {email} from {request.remote_addr}")
            # Reflective response — echoes the full reset URL (incl. Host header value)
            message = (
                f"Password reset instructions have been dispatched to {email}. "
                f"Reset link: {reset_url}"
            )
            success = True
        else:
            message = "No account associated with that email address."
    return render_template('forgot_password.html', message=message, success=success)

@app.route('/reset-password', methods=['GET', 'POST'])
def reset_password():
    token = request.args.get('token') or request.form.get('token', '')
    error = None
    done  = False

    conn  = get_db()
    row   = conn.execute(
        'SELECT * FROM reset_tokens WHERE token = ?', (token,)
    ).fetchone()
    conn.close()

    if not row:
        error = "This reset link is invalid or has already been used."
        return render_template('reset_password.html', error=error, token=None)

    if request.method == 'POST':
        new_pw = request.form.get('new_password', '')
        if len(new_pw) < 8:
            error = "Password must be at least 8 characters."
        else:
            conn = get_db()
            conn.execute(
                'UPDATE users SET password = ? WHERE email = ?',
                (hash_pw(new_pw), row['email'])
            )
            conn.execute('DELETE FROM reset_tokens WHERE token = ?', (token,))
            conn.commit()
            conn.close()
            logging.info(f"Password reset completed for {row['email']}")
            done = True

    return render_template('reset_password.html', token=token, error=error, done=done)

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))
    user = session['user']
    internal_info = None
    if user.get('role') == 'admin':
        internal_info = {
            'mail_relay_host': '203.x.x.x',
            'mail_relay_port': 25,
            'mail_relay_note': 'Internal SMTP relay — IT Operations Division',
            'mail_relay_user': 'Not required (relay configured for v-Public subnet)',
        }
    return render_template('dashboard.html', user=user, internal_info=internal_info)

# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
