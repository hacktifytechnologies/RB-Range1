#!/usr/bin/env bash
# =============================================================================
# M4 — itgw-netmgmt | Honeytrap Decoy
# Decoy: Fake SNMP trap receiver on UDP port 9161 (no conflict with M4 port 161)
# Ubuntu 22.04 LTS
# =============================================================================
set -euo pipefail

DECOY_PORT=9161
LOG_DIR="/var/log/pul-honeytrap"
SERVICE_NAME="pul-decoy-m4"
DECOY_SCRIPT="/opt/pul-honeytrap/M4-decoy-itgw-netmgmt.py"

if [[ $EUID -ne 0 ]]; then echo "[!] Must be run as root." >&2; exit 1; fi

echo "[*] Deploying M4 Honeytrap — Decoy SNMP Trap Receiver on UDP port ${DECOY_PORT}"
mkdir -p "${LOG_DIR}" /opt/pul-honeytrap

cat > "${DECOY_SCRIPT}" << 'PYEOF'
#!/usr/bin/env python3
"""PUL Honeytrap — M4 Decoy SNMP Trap Receiver on UDP 9161"""
import socket, logging, os

LOG_FILE  = "/var/log/pul-honeytrap/M4-decoy-itgw-netmgmt.log"
BIND_PORT = 9161
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
logging.basicConfig(filename=LOG_FILE, level=logging.WARNING,
                    format="%(asctime)s %(message)s", datefmt="%Y-%m-%dT%H:%M:%S")

with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as srv:
    srv.bind(("0.0.0.0", BIND_PORT))
    logging.warning(f"HONEYTRAP_START | port={BIND_PORT}/udp")
    while True:
        try:
            data, addr = srv.recvfrom(4096)
            logging.warning(
                f"HONEYTRAP_HIT | src={addr[0]}:{addr[1]} | "
                f"bytes={len(data)} | hex={data[:32].hex()}"
            )
        except Exception as e:
            logging.warning(f"HONEYTRAP_ERR | err={e}")
PYEOF

chmod +x "${DECOY_SCRIPT}"

cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=PUL Honeytrap Decoy — M4 SNMP Trap (UDP ${DECOY_PORT})
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 ${DECOY_SCRIPT}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}" --quiet
systemctl restart "${SERVICE_NAME}"
sleep 1
systemctl is-active --quiet "${SERVICE_NAME}" && \
    echo "[+] M4 Honeytrap active on UDP port ${DECOY_PORT}." || \
    { echo "[!] Honeytrap failed." >&2; exit 1; }
