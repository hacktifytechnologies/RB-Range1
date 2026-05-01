#!/usr/bin/env bash
# =============================================================================
# M5 — itgw-cache | Honeytrap Decoy
# Decoy: Fake Redis on port 6380 (secondary, no conflict with M5 port 6379)
# Ubuntu 22.04 LTS
# =============================================================================
set -euo pipefail

DECOY_PORT=6380
LOG_DIR="/var/log/pul-honeytrap"
SERVICE_NAME="pul-decoy-m5"
DECOY_SCRIPT="/opt/pul-honeytrap/M5-decoy-itgw-cache.py"

if [[ $EUID -ne 0 ]]; then echo "[!] Must be run as root." >&2; exit 1; fi

echo "[*] Deploying M5 Honeytrap — Decoy Redis on port ${DECOY_PORT}"
mkdir -p "${LOG_DIR}" /opt/pul-honeytrap

cat > "${DECOY_SCRIPT}" << 'PYEOF'
#!/usr/bin/env python3
"""PUL Honeytrap — M5 Decoy Redis on port 6380"""
import socket, threading, logging, os

LOG_FILE  = "/var/log/pul-honeytrap/M5-decoy-itgw-cache.log"
BIND_PORT = 6380
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
logging.basicConfig(filename=LOG_FILE, level=logging.WARNING,
                    format="%(asctime)s %(message)s", datefmt="%Y-%m-%dT%H:%M:%S")

# Fake Redis inline response banner
FAKE_BANNER = b"+PONG\r\n"
FAKE_AUTH   = b"-ERR WRONGPASS invalid username-password pair or user is disabled.\r\n"

def handle(conn, addr):
    try:
        data = conn.recv(1024).decode("utf-8", errors="replace").strip()
        first_line = data.split("\n")[0] if data else "<empty>"
        logging.warning(
            f"HONEYTRAP_HIT | src={addr[0]}:{addr[1]} | cmd={repr(first_line)}"
        )
        # Respond with fake Redis-like error (appears to require auth)
        if "PING" in data.upper():
            conn.sendall(b"-NOAUTH Authentication required.\r\n")
        else:
            conn.sendall(b"-NOAUTH Authentication required.\r\n")
    except Exception as e:
        logging.warning(f"HONEYTRAP_ERR | src={addr[0]}:{addr[1]} | err={e}")
    finally:
        conn.close()

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", BIND_PORT))
    srv.listen(10)
    logging.warning(f"HONEYTRAP_START | port={BIND_PORT}")
    while True:
        try:
            conn, addr = srv.accept()
            threading.Thread(target=handle, args=(conn, addr), daemon=True).start()
        except Exception:
            pass
PYEOF

chmod +x "${DECOY_SCRIPT}"

cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=PUL Honeytrap Decoy — M5 Redis Secondary (port ${DECOY_PORT})
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
    echo "[+] M5 Honeytrap active on port ${DECOY_PORT}." || \
    { echo "[!] Honeytrap failed." >&2; exit 1; }
