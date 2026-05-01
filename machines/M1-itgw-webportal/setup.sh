#!/usr/bin/env bash
# =============================================================================
# M1 — itgw-webportal | setup.sh
# Challenge: HTTP Host Header Injection in Password Reset
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

# ── Pre-create log file (owned by app user) ───────────────────────────────────
touch "${LOG_DIR}/app.log" "${LOG_DIR}/reset_requests.log"
chown "${APP_USER}:${APP_USER}" "${LOG_DIR}/app.log" "${LOG_DIR}/reset_requests.log"
chmod 640 "${LOG_DIR}/app.log" "${LOG_DIR}/reset_requests.log"

# ── Systemd service unit ──────────────────────────────────────────────────────
echo "[*] Configuring systemd service..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
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
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" --quiet
systemctl restart "${SERVICE_NAME}"
sleep 2

# ── Verify service is running ─────────────────────────────────────────────────
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "[+] Service '${SERVICE_NAME}' is running on port ${APP_PORT}."
else
    echo "[!] Service failed to start. Check: journalctl -u ${SERVICE_NAME} -n 30" >&2
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
echo "  Portal URL : http://$(hostname -I | awk '{print $1}'):${APP_PORT}"
echo "  App Dir    : ${APP_DIR}"
echo "  Logs       : ${LOG_DIR}"
echo "  DB         : ${DATA_DIR}/users.db"
echo "  Service    : systemctl status ${SERVICE_NAME}"
echo "============================================================"
