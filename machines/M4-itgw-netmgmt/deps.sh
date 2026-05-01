#!/usr/bin/env bash
# =============================================================================
# M4 — itgw-netmgmt | deps.sh
# Dependency installer — run ONCE manually on the VM before taking snapshot.
# Ubuntu 22.04 LTS | Requires internet access.
# =============================================================================
set -euo pipefail

echo "============================================================"
echo "  RNG-IT-01 | M4-itgw-netmgmt | Dependency Installer"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

apt-get update -qq
apt-get install -y --no-install-recommends \
    snmpd \
    snmp \
    snmp-mibs-downloader \
    python3 \
    net-tools \
    procps \
    curl

echo ""
echo "[+] M4 dependencies installed."
echo "    snmpd  : $(snmpd --version 2>&1 | head -1 || echo installed)"
echo "[!] Run setup.sh to configure the challenge."
