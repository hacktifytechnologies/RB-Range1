#!/usr/bin/env bash
# =============================================================================
# M1 — itgw-webportal | setup.sh
# Challenge: HTTP Host Header Injection in Password Reset
#            Trigger condition: Host header must be exactly 127.0.0.1
# Range: RNG-IT-01 | OPERATION GRIDFALL
# Ubuntu 22.04 LTS | No internet access required — run deps.sh first.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Config ────────────────────────────────────────────────────────────────────
APP_USER="pulportal"
APP_DIR="/opt/pul-portal"
LOG_DIR="/var/log/pul-portal"
DATA_DIR="${APP_DIR}/data"
SERVICE_NAME="pul-portal"
APP_PORT=8080
HOST_HEADER_TRIGGER="127.0.0.1"

HOST_IP="$(hostname -I | awk '{print $1}')"
PUBLIC_HOST="${PUBLIC_HOST:-${HOST_IP}:${APP_PORT}}"

APP_PY="${APP_DIR}/app/app.py"


echo "============================================================"
echo "  RNG-IT-01 | M1-itgw-webportal | Challenge Setup"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

# ── Preflight checks ──────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "[!] This script must be run as root." >&2
    exit 1
fi

command -v python3 >/dev/null 2>&1 || { echo "[!] python3 not found. Run deps.sh first." >&2; exit 1; }
command -v flask   >/dev/null 2>&1 || python3 -c "import flask" 2>/dev/null || \
    { echo "[!] Flask not found. Run deps.sh first." >&2; exit 1; }

echo "[*] Preflight checks passed."

# ── Create system user ────────────────────────────────────────────────────────
if ! id -u "${APP_USER}" &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin \
            --comment "PUL Portal Service Account" "${APP_USER}"
    echo "[+] System user '${APP_USER}' created."
else
    echo "[~] System user '${APP_USER}' already exists, skipping."
fi

# ── Directory layout ──────────────────────────────────────────────────────────
echo "[*] Creating directory layout..."
mkdir -p "${APP_DIR}/app/templates" "${DATA_DIR}" "${LOG_DIR}"

# ── Copy application files ────────────────────────────────────────────────────
echo "[*] Deploying application files..."
cp -r "${SCRIPT_DIR}/app/"* "${APP_DIR}/app/"

# Ensure templates are in place
if [[ ! -f "${APP_DIR}/app/templates/base.html" ]]; then
    echo "[!] Template files missing from ${SCRIPT_DIR}/app/templates/" >&2
    exit 1
fi

if [[ ! -f "${APP_PY}" ]]; then
    echo "[!] Application file missing: ${APP_PY}" >&2
    exit 1
fi

# ── Patch challenge behavior ──────────────────────────────────────────────────
# Required behavior:
#   - Password reset token generation must ONLY happen when Host is exactly 127.0.0.1.
#   - Password reset token usage must ONLY happen when Host is exactly 127.0.0.1.
#   - Requests with Host: attacker.com, Host: <public-ip>, or any other host are denied
#     before the original forgot/reset route can generate or consume a token.
#
# Participant path:
#   curl http://<target>:8080/forgot-password -H "Host: 127.0.0.1" ...
#   curl http://<target>:8080/reset-password -H "Host: 127.0.0.1" ...

echo "[*] Patching Flask app so password reset only works with Host: ${HOST_HEADER_TRIGGER}..."

python3 - <<'PYAPP'
from pathlib import Path
import re
import sys

app_path = Path("/opt/pul-portal/app/app.py")
text = app_path.read_text()

old_block = re.compile(
    r"\n# --- PUL LAB PATCH: 127\.0\.0\.1-only reset gate ---.*?# --- END PUL LAB PATCH ---\n",
    re.DOTALL,
)
text = old_block.sub("\n", text)

patch = r'''
# --- PUL LAB PATCH: 127.0.0.1-only reset gate ---
# Intentional lab behavior:
# Password reset generation and password reset completion are only reachable
# when the HTTP Host header is exactly "127.0.0.1". This prevents arbitrary
# domains like attacker.com from generating usable tokens.
from flask import request as _pul_request, abort as _pul_abort

_PUL_ALLOWED_RESET_HOST = "127.0.0.1"
_PUL_RESET_PATHS = {"/forgot-password", "/reset-password"}


def _pul_normalize_host(raw_host):
    return (raw_host or "").split(",")[0].strip().lower()


@app.before_request
def _pul_enforce_localhost_host_header_for_password_reset():
    if _pul_request.path not in _PUL_RESET_PATHS:
        return None

    incoming_host = _pul_normalize_host(_pul_request.headers.get("Host", ""))

    # Strict by design: only Host: 127.0.0.1 is accepted.
    # Host: attacker.com, Host: <public-ip>:8080, and Host: 127.0.0.1:8080 are denied.
    if incoming_host != _PUL_ALLOWED_RESET_HOST:
        _pul_abort(403, description="You are not authorised to reset password of any user. This will be logged.")

    return None
# --- END PUL LAB PATCH ---
'''

app_pattern = re.compile(r"(?m)^(\s*app\s*=\s*Flask\([^\n]*\)\s*)$")
match = app_pattern.search(text)
if not match:
    print("[!] Unable to find Flask app object line, expected something like: app = Flask(__name__)", file=sys.stderr)
    sys.exit(1)

insert_at = match.end()
text = text[:insert_at] + "\n" + patch + text[insert_at:]
app_path.write_text(text)
print("[+] app.py patched: /forgot-password and /reset-password require Host: 127.0.0.1")
PYAPP

# ── Permissions ───────────────────────────────────────────────────────────────
echo "[*] Setting permissions..."
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}" "${LOG_DIR}"
chmod -R 750 "${APP_DIR}"
chmod 770 "${DATA_DIR}" "${LOG_DIR}"
chmod +x "${APP_DIR}/app/app.py"
chmod +x "${APP_DIR}/app/init_db.py"

# ── Initialise SQLite database ────────────────────────────────────────────────
echo "[*] Initialising challenge database..."
python3 "${APP_DIR}/app/init_db.py"
chown "${APP_USER}:${APP_USER}" "${DATA_DIR}/users.db"
chmod 660 "${DATA_DIR}/users.db"
echo "[+] Database ready."

# Clear any reset tokens generated before this fixed setup was applied.
python3 - <<PYDB
import sqlite3
from pathlib import Path

db = Path("${DATA_DIR}/users.db")
try:
    con = sqlite3.connect(str(db))
    cur = con.cursor()
    cur.execute("DELETE FROM reset_tokens")
    con.commit()
    con.close()
    print("[+] Existing reset tokens cleared from database.")
except Exception as exc:
    print(f"[~] Could not clear reset_tokens: {exc}")
PYDB

# ── Pre-create log file (owned by app user) ───────────────────────────────────
touch "${LOG_DIR}/app.log" "${LOG_DIR}/reset_requests.log"
chown "${APP_USER}:${APP_USER}" "${LOG_DIR}/app.log" "${LOG_DIR}/reset_requests.log"
chmod 640 "${LOG_DIR}/app.log" "${LOG_DIR}/reset_requests.log"

# ── Systemd service unit ──────────────────────────────────────────────────────
echo "[*] Configuring systemd service..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF2
[Unit]
Description=Prabal Urja Limited — Employee Self-Service Portal (M1)
Documentation=https://github.com/hacktifytechnologies/nexus-itgw-range
After=network.target
Wants=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
Environment=PUL_PUBLIC_HOST=${PUBLIC_HOST}
Environment=PUL_HOST_HEADER_TRIGGER=${HOST_HEADER_TRIGGER}
ExecStart=/usr/bin/python3 ${APP_DIR}/app/app.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=${DATA_DIR} ${LOG_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF2

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" --quiet
systemctl restart "${SERVICE_NAME}"
sleep 2

# ── Verify service is running ─────────────────────────────────────────────────
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "[+] Service '${SERVICE_NAME}' is running on port ${APP_PORT}."
else
    echo "[!] Service failed to start. Check: journalctl -u ${SERVICE_NAME} -n 30" >&2
    journalctl -u "${SERVICE_NAME}" -n 30 --no-pager || true
    exit 1
fi

# ── Firewall: open challenge port ─────────────────────────────────────────────
if command -v ufw &>/dev/null; then
    ufw allow "${APP_PORT}/tcp" comment "PUL Portal M1" >/dev/null 2>&1 || true
    echo "[+] ufw rule added for port ${APP_PORT}."
fi

echo ""
echo "============================================================"
echo "  M1 Setup Complete"
echo "  Portal URL            : http://${PUBLIC_HOST}"
echo "  Password Reset Trigger : Host: ${HOST_HEADER_TRIGGER} only"
echo "  Safe Public Host      : ${PUBLIC_HOST}"
echo "  App Dir               : ${APP_DIR}"
echo "  Logs                  : ${LOG_DIR}"
echo "  DB                    : ${DATA_DIR}/users.db"
echo "  Service               : systemctl status ${SERVICE_NAME}"
echo "============================================================"
