#!/usr/bin/env python3
"""
Prabal Urja Limited — Staff Authentication Gateway
M3 Challenge: JWT Algorithm Confusion (alg: none)
Range: RNG-IT-01 | OPERATION GRIDFALL
"""

from flask import (
    Flask, request, render_template, redirect,
    url_for, make_response, g
)
import jwt
import json
import base64
import hashlib
import time
import logging
import os

app = Flask(__name__)

LOG_DIR = '/var/log/pul-sso'
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    filename=f'{LOG_DIR}/sso.log',
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)

JWT_SECRET = 'pul-sso-hs256-secret-2024'
COOKIE_NAME = 'pul_staff_token'

USERS = {
    'svc-deploy-sso': {
        'password_hash': hashlib.sha256('SSO@Prabal!2024'.encode()).hexdigest(),
        'role': 'analyst',
        'name': 'SSO Service Account',
        'dept': 'IT Automation',
    },
    'it.admin': {
        'password_hash': hashlib.sha256('ITA@Secure#99'.encode()).hexdigest(),
        'role': 'analyst',
        'name': 'IT Administrator',
        'dept': 'IT Operations',
    },
}

# Network info shown ONLY to admin-role JWT holders — pivot artifact for M4
ADMIN_INFRA = {
    'snmp_host':      '203.x.x.x',
    'snmp_port':      161,
    'snmp_version':   'v2c',
    'snmp_note':      'Network Management Host — SNMP polling agent',
}


def make_jwt(username: str, role: str) -> str:
    payload = {
        'sub':  username,
        'role': role,
        'iat':  int(time.time()),
        'exp':  int(time.time()) + 3600,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm='HS256')


def decode_jwt_vulnerable(token: str):
    """
    VULNERABILITY: manually decode header to check algorithm,
    then accept 'none' algorithm without signature verification.
    """
    try:
        parts = token.split('.')
        if len(parts) != 3:
            return None

        # Decode header
        header_padded = parts[0] + '=' * (-len(parts[0]) % 4)
        header = json.loads(base64.urlsafe_b64decode(header_padded))

        alg = header.get('alg', '').lower()

        if alg == 'none':
            # VULNERABILITY: skip signature verification entirely for alg:none
            payload_padded = parts[1] + '=' * (-len(parts[1]) % 4)
            payload = json.loads(base64.urlsafe_b64decode(payload_padded))
            logging.warning(
                f"ALG_NONE_ACCEPTED | sub={payload.get('sub')} "
                f"role={payload.get('role')} from={request.remote_addr}"
            )
            return payload

        elif alg == 'hs256':
            payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            return payload

    except Exception as exc:
        logging.warning(f"JWT_DECODE_ERROR | {exc} | from={request.remote_addr}")

    return None


def get_current_user():
    token = request.cookies.get(COOKIE_NAME)
    if not token:
        return None
    return decode_jwt_vulnerable(token)


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    user = get_current_user()
    if user:
        return redirect(url_for('staff_portal'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        pw_hash  = hashlib.sha256(password.encode()).hexdigest()

        user_rec = USERS.get(username)
        if user_rec and user_rec['password_hash'] == pw_hash:
            token = make_jwt(username, user_rec['role'])
            logging.info(f"LOGIN_SUCCESS | user={username} from={request.remote_addr}")
            resp = make_response(redirect(url_for('staff_portal')))
            resp.set_cookie(
                COOKIE_NAME, token,
                httponly=True, samesite='Lax', max_age=3600
            )
            return resp
        else:
            logging.warning(f"LOGIN_FAIL | user={username} from={request.remote_addr}")
            error = 'Invalid service account credentials.'

    return render_template('login.html', error=error)


@app.route('/staff-portal')
def staff_portal():
    user = get_current_user()
    if not user:
        return redirect(url_for('login'))

    token    = request.cookies.get(COOKIE_NAME, '')
    infra    = ADMIN_INFRA if user.get('role') == 'admin' else None
    username = user.get('sub', 'unknown')
    role     = user.get('role', 'analyst')

    logging.info(
        f"PORTAL_ACCESS | user={username} role={role} "
        f"from={request.remote_addr}"
    )
    return render_template(
        'portal.html',
        user=user,
        token_raw=token,
        infra=infra
    )


@app.route('/logout')
def logout():
    resp = make_response(redirect(url_for('login')))
    resp.delete_cookie(COOKIE_NAME)
    return resp


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8443, debug=False)
