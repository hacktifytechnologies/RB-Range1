#!/usr/bin/env bash
# =============================================================================
# M2 — itgw-mailrelay | deps.sh
# Dependency installer — run ONCE manually on the VM before taking snapshot.
# Ubuntu 22.04 LTS | Requires internet access.
# =============================================================================
set -euo pipefail

echo "============================================================"
echo "  RNG-IT-01 | M2-itgw-mailrelay | Dependency Installer"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

echo "[*] Updating apt package index..."
apt-get update -qq

echo "[*] Installing Postfix and mail utilities..."
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    postfix \
    mailutils \
    python3 \
    python3-pip \
    net-tools \
    procps \
    curl

# During postfix install, select 'Local only' — setup.sh reconfigures it
echo "[*] Holding postfix at installed state for reconfiguration in setup.sh..."

echo ""
echo "[+] M2 dependencies installed successfully."
echo "    Postfix : $(postconf mail_version 2>/dev/null | awk '{print $3}' || echo 'installed')"
echo "    Python  : $(python3 --version)"
echo ""
echo "[!] You may now run setup.sh to configure the challenge."
