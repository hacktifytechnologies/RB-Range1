#!/usr/bin/env bash
# =============================================================================
# M1 — itgw-webportal | deps.sh
# Dependency installer — run ONCE manually on the VM before taking snapshot.
# Ubuntu 22.04 LTS | Requires internet access.
# =============================================================================
set -euo pipefail

echo "============================================================"
echo "  RNG-IT-01 | M1-itgw-webportal | Dependency Installer"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

# ── System packages ───────────────────────────────────────────────────────────
echo "[*] Updating apt package index..."
apt-get update -qq

echo "[*] Installing system dependencies..."
apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    sqlite3 \
    curl \
    net-tools \
    procps

# ── Python packages ───────────────────────────────────────────────────────────
echo "[*] Installing Python packages (system-level)..."
pip3 install --quiet \
    flask==2.3.3 \
    werkzeug==2.3.7

echo ""
echo "[+] M1 dependencies installed successfully."
echo "    Python  : $(python3 --version)"
echo "    Flask   : $(pip3 show flask | grep Version | awk '{print $2}')"
echo "    SQLite  : $(sqlite3 --version | awk '{print $1}')"
echo ""
echo "[!] You may now run setup.sh to configure the challenge."
