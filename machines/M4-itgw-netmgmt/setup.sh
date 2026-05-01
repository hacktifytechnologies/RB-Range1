#!/usr/bin/env bash
# =============================================================================
# M4 — itgw-netmgmt | setup.sh
# Challenge: SNMP v2c Weak Community String + Planted Credential OIDs
# Range: RNG-IT-01 | OPERATION GRIDFALL
# Ubuntu 22.04 LTS | No internet access required — run deps.sh first.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SNMPD_CONF="/etc/snmp/snmpd.conf"
SNMPD_CONF_BAK="/etc/snmp/snmpd.conf.orig"
LOG_DIR="/var/log/pul-netmgmt"
SERVICE_NAME="snmpd"

echo "============================================================"
echo "  RNG-IT-01 | M4-itgw-netmgmt | Challenge Setup"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

if [[ $EUID -ne 0 ]]; then echo "[!] Must be run as root." >&2; exit 1; fi

command -v snmpd >/dev/null 2>&1 || { echo "[!] snmpd not found. Run deps.sh first." >&2; exit 1; }

mkdir -p "${LOG_DIR}"
chmod 750 "${LOG_DIR}"

# Backup original config
if [[ ! -f "${SNMPD_CONF_BAK}" ]]; then
    cp "${SNMPD_CONF}" "${SNMPD_CONF_BAK}"
    echo "[+] Original snmpd.conf backed up."
fi

# ── Write vulnerable snmpd.conf ───────────────────────────────────────────────
echo "[*] Writing vulnerable snmpd configuration..."

cat > "${SNMPD_CONF}" << 'EOF'
# =============================================================================
# PUL Network Management Host — SNMP Configuration
# Managed by: IT Infrastructure Division, Prabal Urja Limited
# Reference: PUL-IT-NET-0012
# =============================================================================

# ── Agent settings ─────────────────────────────────────────────────────────
agentAddress  udp:0.0.0.0:161
agentAddress6 udp6:[::1]:161

# ── System information ──────────────────────────────────────────────────────
sysLocation    "PUL Data Centre — Zone B, Rack 14, Unit 3"
sysContact     netops@prabalurja.in
sysName        netmgmt.prabalurja.in
sysDescr       "Prabal Urja Limited Network Management Agent v2.1"

# ── VULNERABILITY: Weak/default community string, world-accessible ──────────
# rocommunity = read-only community
# INSECURE: community string 'public' accessible from all sources
rocommunity public  default
rocommunity pul-net 203.0.0.0/8

# ── Standard MIB views ──────────────────────────────────────────────────────
view   systemonly  included   .1.3.6.1.2.1.1
view   systemonly  included   .1.3.6.1.2.1.25.1

# ── Interface and routing table access ──────────────────────────────────────
view   all         included   .1

# ── PLANTED ARTEFACTS via extend directives ──────────────────────────────────
# These are misconfigured "monitoring checks" that expose internal credential
# material in SNMP OIDs — maps to real-world LOTL/RedEcho tradecraft

# OID .1.3.6.1.4.1.99999.1 — Internal segment note
extend  pul-segment-info   /bin/echo "Target: 203.x.x.x/24 (IT-Ops internal) via gateway 203.x.x.x"

# OID .1.3.6.1.4.1.99999.2 — Credential fragment A (split for difficulty)
extend  pul-cred-part1     /bin/echo "redis-svc-user:r3d"

# OID .1.3.6.1.4.1.99999.3 — Credential fragment B
extend  pul-cred-part2     /bin/echo "1s-cache@PUL!2024"

# OID .1.3.6.1.4.1.99999.4 — Cache host hint
extend  pul-cache-host     /bin/echo "Cache endpoint: 203.x.x.x port 6379"

# ── Logging ──────────────────────────────────────────────────────────────────
# SNMP access logs written by snmpd to syslog — readable at /var/log/syslog
EOF

echo "[+] snmpd.conf written."

# ── Restart snmpd ─────────────────────────────────────────────────────────────
echo "[*] Enabling and restarting snmpd..."
systemctl enable "${SERVICE_NAME}" --quiet
systemctl restart "${SERVICE_NAME}"
sleep 2

if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "[+] snmpd running on UDP port 161."
else
    echo "[!] snmpd failed to start. Check: journalctl -u snmpd -n 20" >&2
    exit 1
fi

# ── Firewall ──────────────────────────────────────────────────────────────────
if command -v ufw &>/dev/null; then
    ufw allow 161/udp comment "SNMP M4 challenge" >/dev/null 2>&1 || true
fi

echo ""
echo "============================================================"
echo "  M4 Setup Complete"
echo "  SNMP Host    : $(hostname -I | awk '{print $1}'):161/udp"
echo "  Community    : public (v2c)"
echo "  Test cmd     : snmpwalk -v2c -c public <IP> .1.3.6.1.4.1.99999"
echo "  Service      : systemctl status snmpd"
echo "  Artifact OIDs: .1.3.6.1.4.1.99999.{1,2,3,4}"
echo "============================================================"
