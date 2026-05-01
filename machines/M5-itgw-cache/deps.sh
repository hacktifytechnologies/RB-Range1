#!/usr/bin/env bash
# =============================================================================
# M5 — itgw-cache | deps.sh
# Dependency installer — run ONCE manually on the VM before taking snapshot.
# Ubuntu 22.04 LTS | Requires internet access.
# =============================================================================
set -euo pipefail

echo "============================================================"
echo "  RNG-IT-01 | M5-itgw-cache | Dependency Installer"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

apt-get update -qq
apt-get install -y --no-install-recommends \
    redis-server \
    redis-tools \
    python3 \
    python3-pip \
    net-tools \
    procps \
    curl

echo ""
echo "[+] M5 dependencies installed."
echo "    Redis  : $(redis-server --version | head -1)"
echo "[!] Run setup.sh to configure the challenge."
