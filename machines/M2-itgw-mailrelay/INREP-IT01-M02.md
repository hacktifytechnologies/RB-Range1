# Incident Notification Report (INREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** INREP-IT01-M02
**Version:** 1.0
**Date:** [Date of Detection]
**Time:** [Time of Detection — IST]

---

## 1. Current Situation

**Description:**
The PUL internal SMTP relay (`203.x.x.x:25`) has been identified as an open relay — it accepts unauthenticated SMTP connections from any source IP (`mynetworks = 0.0.0.0/0`) and allows user enumeration via the VRFY command. Additionally, the mail spool for the `socanalyst` account (`/var/mail/socanalyst`) is world-readable (permissions: `644`). A seeded internal email in this spool contains a base64-encoded SSO service account credential in a non-standard header (`X-Internal-Auth-Token`). An adversary accessing this machine via the pivot from M1 can enumerate users, demonstrate open relay, read the spool, decode the credential, and advance to M3.

**Threat Level:** `HIGH`

**Areas of Concern:**
- Unauthenticated SMTP relay usable for phishing and spoofing under PUL's domain.
- User account enumeration possible via VRFY with no rate-limit.
- SSO service account credential (`svc-deploy-sso`) exposed via mail header — credential for M3 is compromised.

---

## 2. Threat Intelligence

**Sources:**
- `/var/log/mail.log` — Postfix connection and relay logs.
- `/var/mail/socanalyst` — Mail spool with embedded credential.

**Indicators of Compromise:**

| IOC Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Attack Vector | Unauthenticated SMTP connection + VRFY + spool read |
| Compromised Header | `X-Internal-Auth-Token` in `/var/mail/socanalyst` |
| Decoded Credential | `svc-deploy-sso:SSO@Prabal!2024` |

**Log Entry Identified:**
```
postfix/smtpd: connect from unknown[203.0.1.X]
postfix/smtpd: NOQUEUE: ... RCPT from unknown[203.0.1.X]: 250 OK (relay accepted)
```

---

## 3. Vulnerability Identification

**Vulnerability 1:** Postfix `mynetworks = 0.0.0.0/0` — allows any IP to relay mail without authentication.
**Vulnerability 2:** `disable_vrfy_command = no` — exposes user enumeration via VRFY.
**Vulnerability 3:** `/var/mail/socanalyst` permissions `644` — world-readable.
**Vulnerability 4:** SSO credential embedded in email header — credential in plaintext (base64 is not encryption).

**Patch Status:** Pending. See `solve_blue.md` for remediation steps.

---

## 4. Security Operations

**Prevention Steps:**
- Set `mynetworks` to include only trusted relay IPs.
- Set `disable_vrfy_command = yes` in Postfix main.cf.
- Set mail spool permissions to `660` (`chown user:mail`, `chmod 660`).
- Never transmit credentials via email headers — use a secrets manager.
- Implement SASL authentication for any required relay functionality.

---

## 5. POC (Screenshots)

> **[Attach: nc session showing unauthenticated EHLO and relay acceptance]**

> **[Attach: VRFY output showing user enumeration]**

> **[Attach: cat /var/mail/socanalyst output with X-Internal-Auth-Token visible]**

> **[Attach: base64 decode output showing plaintext credential]**

---

## 6. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M02
