# Situation Report (SITREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** SITREP-IT01-M02
**Version:** 1.0
**Date:** [Date of Incident]
**Time:** [Time of Detection — IST]
**Incident ID:** GRIDFALL-RNG-IT01-M02

---

## 1. Incident Overview

**Description:**
- SMTP Open Relay abuse on PUL mail relay (`203.x.x.x:25`) — unauthenticated relay accepted from external attacker IP on v-Public segment.
- User enumeration via VRFY command — `socanalyst` and `it.admin` accounts confirmed.
- World-readable mail spool `/var/mail/socanalyst` accessed — internal email containing `X-Internal-Auth-Token` header with base64-encoded SSO credential read by attacker.
- Credential `svc-deploy-sso:SSO@Prabal!2024` decoded and exfiltrated — pivots to M3 (itgw-sso).

**Severity Level:** `HIGH`
**Impact:** `SEVERE` — SSO service account credential compromised; pivot to identity infrastructure imminent.

**Affected Systems:**

| Machine | IP | Service | Impact |
|---|---|---|---|
| M2 — itgw-mailrelay | `203.x.x.x` | Postfix SMTP (port 25) | Open relay; user enumeration; SSO credential exfiltrated |

---

## 2. Incident Details

**Detection Method:**
- `/var/log/mail.log` reviewed — unauthenticated SMTP connection from external IP with relay acceptance logged.
- VRFY responses in Postfix log — bulk enumeration pattern detected.
- Mail spool permission audit — `/var/mail/socanalyst` found to be world-readable (`644`).

**Initial Detection Time:** `[Timestamp of first anomalous Postfix log entry]`

**Attack Vector:** Postfix open relay (no auth) → VRFY user enumeration → world-readable spool read → credential header extracted and decoded.

**Attack Sequence:**

1. Attacker connects to port 25 from `203.0.1.X` — EHLO issued, no AUTH in capabilities.
2. VRFY commands issued — `socanalyst`, `it.admin` confirmed as valid accounts.
3. Open relay demonstrated — unauthenticated MAIL FROM / RCPT TO / DATA accepted.
4. Attacker reads `/var/mail/socanalyst` (world-readable, chmod 644).
5. `X-Internal-Auth-Token: c3ZjLWRlcGxveS1zc286U1NPQFByYWJhbCEyMDI0` extracted.
6. Base64 decoded: `svc-deploy-sso:SSO@Prabal!2024`.
7. Credential documented — pivot to M3 (itgw-sso) initiated.

---

## 3. Response Actions Taken

**Containment:**
- Open relay restricted: `mynetworks` updated to `127.0.0.0/8 203.x.x.x/32`.
- VRFY disabled: `disable_vrfy_command = yes`, Postfix reloaded.
- Mail spool permissions hardened: `chmod 660 /var/mail/socanalyst`.
- Attacker source IP blocked at UFW.

**Eradication:**
- Root causes addressed: Postfix relay policy, VRFY policy, spool permissions.
- Seeded email with embedded credential removed from spool.
- `svc-deploy-sso` credential rotation notification sent to M3 team.
- IT policy PUL-IT-POL-0044 flagged for review — automated credential distribution via email is prohibited.

**Recovery:**
- SASL authentication enabled for SMTP relay.
- Mail monitoring alert rule deployed for unauthenticated relay attempts.
- SPF record review initiated for `prabalurja.in`.

**Lessons Learned:**
- Mail relays must enforce authentication. Open relay is never acceptable on internet-facing or v-Public segments.
- Mail spool permissions must follow least-privilege: `660`, owned by `user:mail`.
- Credentials must never be transmitted via email — use a secrets management system.
- Periodic mail header audits should be part of the SOC playbook.

---

## 4. Technical Analysis

**Evidence:**

| Artefact | Location | Relevance |
|---|---|---|
| Relay acceptance log | `/var/log/mail.log` | Confirms unauthenticated relay |
| VRFY log entries | `/var/log/mail.log` | Confirms user enumeration |
| Mail spool | `/var/mail/socanalyst` | Source of credential exposure |
| Encoded token | `X-Internal-Auth-Token` header | Embedded credential (base64) |
| Decoded credential | `svc-deploy-sso:SSO@Prabal!2024` | Pivot artifact to M3 |

**TTPs:**

**Application Layer Protocol: Mail Protocols (T1071.003)**
Adversary used standard SMTP protocol to enumerate users and relay mail without authentication, blending with legitimate mail traffic.

**Email Collection: Local Email Collection (T1114.001)**
Adversary read the local mail spool directly from the filesystem, exploiting world-readable permissions to access internal communications containing credential material.

**Unsecured Credentials (T1552)**
A service account credential was stored in a non-standard email header in plaintext (base64 encoded — not encrypted), allowing trivial extraction.

**Mitigation Recommendations:**
- Enforce `smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination`.
- Set `disable_vrfy_command = yes` and `disable_expn_command = yes` globally.
- Implement file integrity monitoring on `/var/mail/` — alert on world-readable spool files.
- Integrate a secrets management workflow: service credentials distributed via Vault, not email.

---

## 5. Communication

**Internal Notification:**
- **SOC Lead:** Immediate — M2 credential exfiltration declared at `[TIME]`
- **IT Infrastructure / SSO Team:** Urgent — `svc-deploy-sso` credential rotation required before M3 is accessed.
- **CISO:** Updated on credential chain compromise spanning M1 → M2 → M3.

**External Notification:**
- **CERT-In:** Notification pending — credential of a service account with SSO-level access has been compromised.

---

## 6. POC (Screenshots)

> **[Attach: nc SMTP session showing unauthenticated relay acceptance]**

> **[Attach: VRFY output confirming valid user accounts]**

> **[Attach: cat /var/mail/socanalyst — X-Internal-Auth-Token header visible]**

> **[Attach: base64 -d output showing decoded credential]**

---

## 7. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M02
