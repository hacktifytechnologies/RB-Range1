#!/usr/bin/env bash
# =============================================================================
# M3 — itgw-sso | setup.sh
# Challenge: JWT Algorithm Confusion (alg: none)
# Range: RNG-IT-01 | OPERATION GRIDFALL
# Ubuntu 22.04 LTS | No internet access required — run deps.sh first.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_USER="pulsso"
APP_DIR="/opt/pul-sso"
LOG_DIR="/var/log/pul-sso"
SERVICE_NAME="pul-sso"
APP_PORT=8443

echo "============================================================"
echo "  RNG-IT-01 | M3-itgw-sso | Challenge Setup"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

if [[ $EUID -ne 0 ]]; then echo "[!] Must be run as root." >&2; exit 1; fi

command -v python3 >/dev/null 2>&1 || { echo "[!] python3 not found. Run deps.sh first." >&2; exit 1; }
python3 -c "import flask, jwt" 2>/dev/null || { echo "[!] Flask/PyJWT not found. Run deps.sh first." >&2; exit 1; }

# ── System user ───────────────────────────────────────────────────────────────
if ! id -u "${APP_USER}" &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin \
            --comment "PUL SSO Gateway Service" "${APP_USER}"
    echo "[+] User '${APP_USER}' created."
else
    echo "[~] User '${APP_USER}' exists."
fi

# ── Directories ───────────────────────────────────────────────────────────────
mkdir -p "${APP_DIR}/app/templates" "${LOG_DIR}"
cp -r "${SCRIPT_DIR}/app/"* "${APP_DIR}/app/"

[[ -f "${APP_DIR}/app/templates/base.html" ]] || \
    { echo "[!] Templates missing from ${SCRIPT_DIR}/app/templates/" >&2; exit 1; }

# ── Permissions ───────────────────────────────────────────────────────────────
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}" "${LOG_DIR}"
chmod -R 750 "${APP_DIR}"
chmod 770 "${LOG_DIR}"
chmod +x "${APP_DIR}/app/app.py"
touch "${LOG_DIR}/sso.log"
chown "${APP_USER}:${APP_USER}" "${LOG_DIR}/sso.log"
chmod 640 "${LOG_DIR}/sso.log"

# ── Systemd service ───────────────────────────────────────────────────────────
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Prabal Urja Limited — Staff Authentication Gateway (M3)
After=network.target

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
ReadWritePaths=${LOG_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" --quiet
systemctl restart "${SERVICE_NAME}"
sleep 2

if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "[+] SSO Gateway running on port ${APP_PORT}."
else
    echo "[!] Service failed. Check: journalctl -u ${SERVICE_NAME} -n 30" >&2; exit 1
fi

if command -v ufw &>/dev/null; then
    ufw allow "${APP_PORT}/tcp" comment "PUL SSO M3" >/dev/null 2>&1 || true
fi

echo ""
echo "============================================================"
echo "  M3 Setup Complete"
echo "  Portal URL : http://$(hostname -I | awk '{print $1}'):${APP_PORT}"
echo "  Logs       : ${LOG_DIR}/sso.log"
echo "  Service    : systemctl status ${SERVICE_NAME}"
echo "============================================================"
