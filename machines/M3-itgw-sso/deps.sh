#!/usr/bin/env bash
# =============================================================================
# M3 — itgw-sso | deps.sh
# Dependency installer — run ONCE manually on the VM before taking snapshot.
# Ubuntu 22.04 LTS | Requires internet access.
# =============================================================================
set -euo pipefail

echo "============================================================"
echo "  RNG-IT-01 | M3-itgw-sso | Dependency Installer"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

apt-get update -qq
apt-get install -y --no-install-recommends \
    python3 python3-pip net-tools procps curl

pip3 install --quiet flask==2.3.3 werkzeug==2.3.7 PyJWT==2.8.0

echo ""
echo "[+] M3 dependencies installed."
echo "    Flask  : $(pip3 show flask | grep Version | awk '{print $2}')"
echo "    PyJWT  : $(pip3 show PyJWT | grep Version | awk '{print $2}')"
echo "[!] Run setup.sh to configure the challenge."
