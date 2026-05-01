#!/usr/bin/env bash
# =============================================================================
# M5 — itgw-cache | setup.sh
# Challenge: Redis No-Auth Exposure + Sensitive Key Data Harvest
# Range: RNG-IT-01 | OPERATION GRIDFALL
# Ubuntu 22.04 LTS | No internet access required — run deps.sh first.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REDIS_CONF="/etc/redis/redis.conf"
REDIS_CONF_BAK="/etc/redis/redis.conf.orig"
LOG_DIR="/var/log/pul-cache"
LOG_FILE="${LOG_DIR}/redis.log"
REDIS_DATA_DIR="/var/lib/redis"
SERVICE_NAME="redis-server"
REDIS_USER="redis"
REDIS_GROUP="redis"
SYSTEMD_OVERRIDE_DIR="/etc/systemd/system/${SERVICE_NAME}.service.d"
SYSTEMD_OVERRIDE_FILE="${SYSTEMD_OVERRIDE_DIR}/pul-cache-override.conf"

echo "============================================================"
echo "  RNG-IT-01 | M5-itgw-cache | Challenge Setup"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

# ── Root Check ────────────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    echo "[!] Must be run as root." >&2
    exit 1
fi

# ── Dependency Check ──────────────────────────────────────────────────────────
if ! command -v redis-server >/dev/null 2>&1; then
    echo "[!] redis-server not found. Run deps.sh first." >&2
    exit 1
fi

if ! command -v redis-cli >/dev/null 2>&1; then
    echo "[!] redis-cli not found. Run deps.sh first." >&2
    exit 1
fi

if ! id "${REDIS_USER}" >/dev/null 2>&1; then
    echo "[!] Redis user '${REDIS_USER}' not found. Check redis-server installation." >&2
    exit 1
fi

# ── Stop Redis Before Reconfiguration ─────────────────────────────────────────
echo "[*] Stopping Redis service if already running..."

systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
systemctl reset-failed "${SERVICE_NAME}" >/dev/null 2>&1 || true

# ── Prepare Log Directory ─────────────────────────────────────────────────────
echo "[*] Preparing Redis log directory..."

mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"

chown -R "${REDIS_USER}:${REDIS_GROUP}" "${LOG_DIR}"
chmod 750 "${LOG_DIR}"
chmod 640 "${LOG_FILE}"

echo "[+] Redis log directory ready: ${LOG_FILE}"

# ── Prepare Data Directory ────────────────────────────────────────────────────
echo "[*] Preparing Redis data directory..."

mkdir -p "${REDIS_DATA_DIR}"
chown -R "${REDIS_USER}:${REDIS_GROUP}" "${REDIS_DATA_DIR}"
chmod 750 "${REDIS_DATA_DIR}"

echo "[+] Redis data directory ready: ${REDIS_DATA_DIR}"

# ── Systemd Hardening Fix ─────────────────────────────────────────────────────
# Ubuntu's redis-server.service may restrict write access through systemd
# hardening options. This override explicitly allows Redis to write to the
# custom challenge log directory.

echo "[*] Applying systemd Redis write-path override..."

mkdir -p "${SYSTEMD_OVERRIDE_DIR}"

cat > "${SYSTEMD_OVERRIDE_FILE}" << EOF
[Service]
ReadWritePaths=${LOG_DIR} ${REDIS_DATA_DIR} /run/redis
EOF

chmod 644 "${SYSTEMD_OVERRIDE_FILE}"

systemctl daemon-reload
systemctl reset-failed "${SERVICE_NAME}" >/dev/null 2>&1 || true

echo "[+] Systemd override applied: ${SYSTEMD_OVERRIDE_FILE}"

# ── Backup Original Config ────────────────────────────────────────────────────
if [[ ! -f "${REDIS_CONF_BAK}" ]]; then
    cp "${REDIS_CONF}" "${REDIS_CONF_BAK}"
    echo "[+] Original redis.conf backed up to ${REDIS_CONF_BAK}"
else
    echo "[*] Backup already exists: ${REDIS_CONF_BAK}"
fi

# ── Write Vulnerable Redis Config ─────────────────────────────────────────────
echo "[*] Configuring Redis with no-auth world-accessible mode..."

cat > "${REDIS_CONF}" << EOF
# =============================================================================
# PUL Application Cache — Redis Configuration
# Managed by: Application Infrastructure Team, Prabal Urja Limited
# Reference: PUL-IT-APP-0031
# =============================================================================

# ── Network ──────────────────────────────────────────────────────────────────
# VULNERABILITY: Bind to all interfaces, no password required
bind 0.0.0.0
protected-mode no
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300

# ── General ──────────────────────────────────────────────────────────────────
daemonize no
supervised systemd
loglevel notice
logfile ${LOG_FILE}
databases 16

# ── Persistence ──────────────────────────────────────────────────────────────
save 900 1
save 300 10
save 60 10000
rdbcompression yes
rdbchecksum yes
dbfilename pul-cache.rdb
dir ${REDIS_DATA_DIR}

# ── Authentication ───────────────────────────────────────────────────────────
# VULNERABILITY: requirepass is intentionally not set — no authentication
# requirepass <disabled>

# ── Memory ───────────────────────────────────────────────────────────────────
maxmemory 128mb
maxmemory-policy allkeys-lru

# ── Slow log ─────────────────────────────────────────────────────────────────
slowlog-log-slower-than 10000
slowlog-max-len 128
EOF

chown root:root "${REDIS_CONF}"
chmod 644 "${REDIS_CONF}"

echo "[+] redis.conf written."

# ── Start Redis ───────────────────────────────────────────────────────────────
echo "[*] Starting Redis service..."

systemctl enable "${SERVICE_NAME}" --quiet
systemctl restart "${SERVICE_NAME}"

sleep 3

if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "[!] Redis failed to start." >&2
    echo ""
    echo "[!] Last Redis service logs:"
    journalctl -u "${SERVICE_NAME}" -n 50 --no-pager
    exit 1
fi

echo "[+] Redis running on port 6379."

# ── Verify Redis Connection ───────────────────────────────────────────────────
echo "[*] Verifying Redis connectivity..."

if ! redis-cli -h 127.0.0.1 -p 6379 ping | grep -q "PONG"; then
    echo "[!] Redis did not respond to PING." >&2
    journalctl -u "${SERVICE_NAME}" -n 50 --no-pager
    exit 1
fi

echo "[+] Redis responded with PONG."

# ── Seed Challenge Data Keys ──────────────────────────────────────────────────
echo "[*] Seeding challenge data keys..."

redis-cli -h 127.0.0.1 -p 6379 SET "pul:session:admin" \
  '{"user":"admin","role":"admin","dept":"IT Infrastructure","ldap_server":"203.x.x.x","ldap_port":389,"bind_dn":"cn=svc-deploy,ou=service,dc=prabalurja,dc=in","bind_pass":"D3pl0y@PUL2024","session_created":"2024-11-15T08:00:00+05:30"}' \
  EX 86400 >/dev/null

redis-cli -h 127.0.0.1 -p 6379 SET "pul:config:ldap" \
  '{"host":"203.x.x.x","port":389,"base_dn":"dc=prabalurja,dc=in","bind_dn":"cn=svc-deploy,ou=service,dc=prabalurja,dc=in","bind_pass":"D3pl0y@PUL2024","tls":false,"note":"Internal LDAP for IT-Ops zone — RNG-IT-02 directory service"}' >/dev/null

redis-cli -h 127.0.0.1 -p 6379 SET "pul:config:app" \
  '{"version":"3.2.1","environment":"production","debug":false,"db_host":"203.x.x.x","db_port":5432,"cache_ttl":3600}' >/dev/null

redis-cli -h 127.0.0.1 -p 6379 LPUSH "pul:queue:deploy" \
  '{"job_id":"JOB-20241115-001","type":"config_push","target":"203.x.x.x/24","initiated_by":"svc-deploy","status":"pending"}' >/dev/null

redis-cli -h 127.0.0.1 -p 6379 SET "pul:ratelimit:203.0.1.X" "0" EX 60 >/dev/null

echo "[+] Challenge data keys seeded."

# ── Verify Seeded Keys ────────────────────────────────────────────────────────
echo "[*] Verifying seeded keys..."

KEY_COUNT="$(redis-cli -h 127.0.0.1 -p 6379 KEYS "pul:*" | wc -l)"

if [[ "${KEY_COUNT}" -eq 0 ]]; then
    echo "[!] No pul:* keys found after seeding." >&2
    exit 1
fi

redis-cli -h 127.0.0.1 -p 6379 KEYS "pul:*" | sort | while read -r key; do
    echo "    [key] ${key}"
done

# ── Firewall ──────────────────────────────────────────────────────────────────
if command -v ufw >/dev/null 2>&1; then
    echo "[*] Updating UFW rules if UFW is enabled..."
    ufw allow 6379/tcp comment "Redis M5 challenge" >/dev/null 2>&1 || true
fi

# ── Final Status ──────────────────────────────────────────────────────────────
HOST_IP="$(hostname -I | awk '{print $1}')"

echo ""
echo "============================================================"
echo "  M5 Setup Complete"
echo "============================================================"
echo "  Redis Host   : ${HOST_IP}:6379"
echo "  Auth         : NONE"
echo "  Log File     : ${LOG_FILE}"
echo "  Systemd Fix  : ${SYSTEMD_OVERRIDE_FILE}"
echo "  Seeded Keys  : pul:session:admin, pul:config:ldap, pul:config:app"
echo "  Pivot Cred   : cn=svc-deploy LDAP bind inside pul:config:ldap"
echo "  Next Range   : RNG-IT-02, 203.x.x.x/24"
echo "  Service      : systemctl status redis-server"
echo "============================================================"
