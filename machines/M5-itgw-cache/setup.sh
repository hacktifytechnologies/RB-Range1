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
SERVICE_NAME="redis-server"

echo "============================================================"
echo "  RNG-IT-01 | M5-itgw-cache | Challenge Setup"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

if [[ $EUID -ne 0 ]]; then echo "[!] Must be run as root." >&2; exit 1; fi

command -v redis-server >/dev/null 2>&1 || { echo "[!] redis-server not found. Run deps.sh first." >&2; exit 1; }

mkdir -p "${LOG_DIR}"
chmod 750 "${LOG_DIR}"

# Backup original config
if [[ ! -f "${REDIS_CONF_BAK}" ]]; then
    cp "${REDIS_CONF}" "${REDIS_CONF_BAK}"
    echo "[+] Original redis.conf backed up."
fi

# ── Write vulnerable redis.conf ───────────────────────────────────────────────
echo "[*] Configuring Redis with no-auth (world-accessible)..."

cat > "${REDIS_CONF}" << 'EOF'
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
logfile /var/log/pul-cache/redis.log
databases 16

# ── Persistence ──────────────────────────────────────────────────────────────
save 900 1
save 300 10
save 60 10000
rdbcompression yes
rdbchecksum yes
dbfilename pul-cache.rdb
dir /var/lib/redis

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

echo "[+] redis.conf written."

# ── Enable and restart Redis ──────────────────────────────────────────────────
systemctl enable "${SERVICE_NAME}" --quiet
systemctl restart "${SERVICE_NAME}"
sleep 2

if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "[!] Redis failed to start. Check: journalctl -u redis-server -n 20" >&2
    exit 1
fi

echo "[+] Redis running on port 6379."

# ── Seed challenge data keys ──────────────────────────────────────────────────
echo "[*] Seeding challenge data keys..."

# Active session key — simulates a live admin session with embedded LDAP info
redis-cli SET "pul:session:admin" \
  '{"user":"admin","role":"admin","dept":"IT Infrastructure","ldap_server":"203.x.x.x","ldap_port":389,"bind_dn":"cn=svc-deploy,ou=service,dc=prabalurja,dc=in","bind_pass":"D3pl0y@PUL2024","session_created":"2024-11-15T08:00:00+05:30"}' \
  EX 86400 >/dev/null

# LDAP configuration key — service bind credential for IT-2 LDAP
redis-cli SET "pul:config:ldap" \
  '{"host":"203.x.x.x","port":389,"base_dn":"dc=prabalurja,dc=in","bind_dn":"cn=svc-deploy,ou=service,dc=prabalurja,dc=in","bind_pass":"D3pl0y@PUL2024","tls":false,"note":"Internal LDAP for IT-Ops zone — RNG-IT-02 directory service"}' >/dev/null

# App config key — general application configuration
redis-cli SET "pul:config:app" \
  '{"version":"3.2.1","environment":"production","debug":false,"db_host":"203.x.x.x","db_port":5432,"cache_ttl":3600}' >/dev/null

# Queue key — simulates a message queue entry
redis-cli LPUSH "pul:queue:deploy" \
  '{"job_id":"JOB-20241115-001","type":"config_push","target":"203.x.x.x/24","initiated_by":"svc-deploy","status":"pending"}' >/dev/null

# Rate limit key — simulates application rate limiting
redis-cli SET "pul:ratelimit:203.0.1.X" "0" EX 60 >/dev/null

echo "[+] Challenge data keys seeded."

# ── Verify seeded keys ────────────────────────────────────────────────────────
echo "[*] Verifying seeded keys..."
redis-cli KEYS "pul:*" | sort | while read -r key; do
    echo "    [key] ${key}"
done

# ── Firewall ──────────────────────────────────────────────────────────────────
if command -v ufw &>/dev/null; then
    ufw allow 6379/tcp comment "Redis M5 challenge" >/dev/null 2>&1 || true
fi

echo ""
echo "============================================================"
echo "  M5 Setup Complete"
echo "  Redis Host   : $(hostname -I | awk '{print $1}'):6379"
echo "  Auth         : NONE (no requirepass configured)"
echo "  Seeded Keys  : pul:session:admin, pul:config:ldap, pul:config:app"
echo "  Pivot Cred   : cn=svc-deploy LDAP bind (see pul:config:ldap)"
echo "  Next Range   : RNG-IT-02 (203.x.x.x/24)"
echo "  Service      : systemctl status redis-server"
echo "============================================================"
