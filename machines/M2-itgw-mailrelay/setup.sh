#!/usr/bin/env bash
# =============================================================================
# M2 — itgw-mailrelay | setup.sh
# Challenge: SMTP Open Relay + Exposed Mail Spool Credential Harvest
# Range: RNG-IT-01 | OPERATION GRIDFALL
# Ubuntu 22.04 LTS | No internet access required — run deps.sh first.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Config ────────────────────────────────────────────────────────────────────
DOMAIN="prabalurja.in"
HOSTNAME="mail.prabalurja.in"
MAIL_USER="socanalyst"
MAIL_USER_PASS="SOC@Relay!77"
SPOOL_FILE="/var/mail/${MAIL_USER}"
LOG_DIR="/var/log/pul-mailrelay"
SERVICE_NAME="postfix"

echo "============================================================"
echo "  RNG-IT-01 | M2-itgw-mailrelay | Challenge Setup"
echo "  Prabal Urja Limited — Operation GRIDFALL"
echo "============================================================"

if [[ $EUID -ne 0 ]]; then
    echo "[!] Must be run as root." >&2; exit 1
fi

command -v postfix >/dev/null 2>&1 || { echo "[!] postfix not found. Run deps.sh first." >&2; exit 1; }

# ── Create mail user ──────────────────────────────────────────────────────────
echo "[*] Creating mail system user '${MAIL_USER}'..."
if ! id -u "${MAIL_USER}" &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin \
            --comment "PUL SOC Analyst Mail Account" "${MAIL_USER}"
    echo "${MAIL_USER}:${MAIL_USER_PASS}" | chpasswd
    echo "[+] User '${MAIL_USER}' created."
else
    echo "[~] User '${MAIL_USER}' exists, ensuring password is set..."
    echo "${MAIL_USER}:${MAIL_USER_PASS}" | chpasswd
fi

# ── Configure Postfix as open relay ──────────────────────────────────────────
echo "[*] Configuring Postfix as open relay..."

# Set hostname
hostnamectl set-hostname "${HOSTNAME}" 2>/dev/null || true
echo "127.0.0.1 ${HOSTNAME} mail localhost" >> /etc/hosts 2>/dev/null || true

postconf -e "myhostname = ${HOSTNAME}"
postconf -e "mydomain = ${DOMAIN}"
postconf -e "myorigin = \$mydomain"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
postconf -e "mynetworks = 0.0.0.0/0"          # VULNERABILITY: open relay
postconf -e "smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, permit"
postconf -e "smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, defer_unauth_destination"
postconf -e "smtpd_client_restrictions ="
postconf -e "smtpd_helo_required = no"
postconf -e "disable_vrfy_command = no"        # VULNERABILITY: VRFY enabled
postconf -e "smtpd_banner = \$myhostname ESMTP Postfix (PUL-IT-Relay/2.1)"
postconf -e "mailbox_command ="
postconf -e "home_mailbox ="
postconf -e "mail_spool_directory = /var/mail"

# ── Seed the malicious artifact mail ─────────────────────────────────────────
echo "[*] Seeding challenge mail in spool for '${MAIL_USER}'..."

mkdir -p "${LOG_DIR}"
touch "${SPOOL_FILE}"
chown "${MAIL_USER}:mail" "${SPOOL_FILE}"
# VULNERABILITY: world-readable mail spool
chmod 644 "${SPOOL_FILE}"

# Write seeded email with embedded credential token in custom header
cat > "${SPOOL_FILE}" << 'MAILEOF'
From it.admin@prabalurja.in Fri Nov 15 08:14:22 2024
Return-Path: <it.admin@prabalurja.in>
Delivered-To: socanalyst@prabalurja.in
Received: from mail.prabalurja.in (mail.prabalurja.in [203.x.x.x])
        by mail.prabalurja.in with ESMTP id A7B3C9D2E1F4
        for <socanalyst@prabalurja.in>; Fri, 15 Nov 2024 08:14:22 +0530
Date: Fri, 15 Nov 2024 08:14:22 +0530
From: IT Administration <it.admin@prabalurja.in>
To: SOC Analyst <socanalyst@prabalurja.in>
Subject: [PUL-IT] Scheduled Maintenance Window — SSO Gateway Credentials
Message-ID: <20241115081422.A7B3C9D2E1F4@mail.prabalurja.in>
MIME-Version: 1.0
Content-Type: text/plain; charset="utf-8"
X-Mailer: PUL-IT-AutoMailer/3.2
X-PUL-Classification: INTERNAL-SENSITIVE
X-Internal-Auth-Token: c3ZjLWRlcGxveS1zc286U1NPQFByYWJhbCEyMDI0

Dear SOC Team,

This is an automated notification from PUL IT Infrastructure.

A maintenance window has been scheduled for the Staff Authentication Gateway
(itgw-sso) on Saturday, 16 Nov 2024, 02:00–04:00 IST.

During this period, authentication services may be briefly unavailable.
Service account credentials for the SSO gateway have been rotated as part
of this maintenance. The updated bind credential has been embedded in this
message header (X-Internal-Auth-Token) per our automated credential
distribution policy (Ref: PUL-IT-POL-0044).

Please ensure the SOC monitoring dashboard is updated accordingly.

For queries, contact IT Operations at it.admin@prabalurja.in.

Regards,
Arun Sharma
IT Infrastructure Lead
Prabal Urja Limited
1800-PUL-HELP | it.admin@prabalurja.in

MAILEOF

chown "${MAIL_USER}:mail" "${SPOOL_FILE}"
chmod 644 "${SPOOL_FILE}"
echo "[+] Seeded mail written to ${SPOOL_FILE}."

# Decode note for white team only (not in any participant-visible file)
# X-Internal-Auth-Token value (base64): svc-deploy-sso:SSO@Prabal!2024
# This is the credential artifact used in M3

# ── Restart Postfix ───────────────────────────────────────────────────────────
echo "[*] Starting Postfix service..."
systemctl enable "${SERVICE_NAME}" --quiet
systemctl restart "${SERVICE_NAME}"
sleep 2

if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "[+] Postfix running."
else
    echo "[!] Postfix failed to start. Check: journalctl -u postfix -n 20" >&2
    exit 1
fi

# ── Firewall ──────────────────────────────────────────────────────────────────
if command -v ufw &>/dev/null; then
    ufw allow 25/tcp comment "SMTP M2 open relay" >/dev/null 2>&1 || true
fi

echo ""
echo "============================================================"
echo "  M2 Setup Complete"
echo "  SMTP Host : $(hostname -I | awk '{print $1}'):25"
echo "  VRFY      : Enabled (enumerate users)"
echo "  Open Relay: YES (mynetworks = 0.0.0.0/0)"
echo "  Mail Spool: ${SPOOL_FILE} (world-readable)"
echo "  Artifact  : X-Internal-Auth-Token header in spool mail"
echo "============================================================"
