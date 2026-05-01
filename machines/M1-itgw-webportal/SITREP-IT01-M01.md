# Situation Report (SITREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** SITREP-IT01-M01
**Version:** 1.0
**Date:** [Date of Incident]
**Time:** [Time of Detection — IST]
**Incident ID:** GRIDFALL-RNG-IT01-M01

---

## 1. Incident Overview

**Description:**
- Host Header Injection attack on PUL Employee Portal (`203.x.x.x:8080`). Attacker manipulated the `Host` header in a password reset POST request to redirect the admin account's reset token to an externally controlled domain. Token was extracted from the reflected HTTP response and used to reset the admin password. Attacker authenticated as admin and accessed the internal infrastructure registry panel exposing the mail relay at `203.x.x.x:25`.

**Severity Level:** `HIGH`

**Impact:** `SEVERE` — Admin-level portal compromise; internal mail relay topology exposed; lateral movement to M2 assessed as in-progress.

**Affected Systems:**

| Machine | IP | Service | Impact |
|---|---|---|---|
| M1 — itgw-webportal | `203.x.x.x` | Flask Portal (port 8080) | Admin account compromised; infra details leaked |

---

## 2. Incident Details

**Detection Method:**
- Manual review of `/var/log/pul-portal/reset_requests.log` — identified reset URL containing attacker-controlled domain (`attacker.com`) instead of the server's canonical address.
- Cross-referenced with `/var/log/pul-portal/app.log` — confirmed successful admin login from attacker source IP immediately after the anomalous reset request.

**Initial Detection Time:** `[Timestamp when reset_requests.log anomaly was first identified]`

**Attack Vector:** HTTP Host Header Injection → Password Reset Token Capture → Credential Reset → Authenticated Admin Session

**Attack Sequence:**
1. Attacker sends `POST /forgot-password` with `Host: attacker.com` and `email=admin@prabalurja.in`
2. Application reflects full reset URL (with token) in response — `http://attacker.com/reset-password?token=<TOKEN>`
3. Attacker extracts token from HTTP response body
4. Attacker sends `POST /reset-password` with captured token and new password
5. Attacker sends `POST /login` with `admin@prabalurja.in` and new password
6. Admin dashboard accessed — mail relay details exfiltrated

---

## 3. Response Actions Taken

**Containment:**
- All active password reset tokens purged from the database (`DELETE FROM reset_tokens`).
- Admin account password rotated to a known-good value by the SOC team.
- Attacker source IP blocked at host firewall (`ufw deny from <IP>`).
- Portal service restarted to clear active sessions.

**Eradication:**
- Root-cause identified: unvalidated `Host` header usage in `forgot_password()` function in `app.py`.
- Patch applied: `Host` header replaced with hardcoded server address `203.x.x.x:8080` in reset URL construction.
- Application redeployed and verified — re-test confirms reflected URL now always uses canonical server address regardless of incoming `Host` header.

**Recovery:**
- Password rotation issued for all accounts that received reset emails during the attack window.
- Rate-limiting added to `/forgot-password` endpoint.
- Monitoring alert rule deployed: trigger on reset log entries where URL domain ≠ `203.x.x.x`.

**Lessons Learned:**
- Flask applications must never derive URLs from request headers for security-sensitive flows (password reset, OAuth callbacks, redirect targets).
- Use `app.config['SERVER_NAME']` or a hardcoded `BASE_URL` environment variable.
- Admin dashboards must not surface internal infrastructure topology without explicit need-to-know gating.
- HTTPS is mandatory on public-facing portals to prevent token interception.
- Implement CERT-In notification procedure for admin-level credential compromises within 6 hours.

---

## 4. Technical Analysis

**Evidence:**

| Artefact | Location | Relevance |
|---|---|---|
| Malicious reset log entry | `/var/log/pul-portal/reset_requests.log` | Confirms Host header manipulation and token generation |
| Successful login log entry | `/var/log/pul-portal/app.log` | Confirms account takeover timestamp |
| Attacker source IP | Network IDS / app log | Attribution |
| Admin dashboard screenshot | POC section | Confirms access scope |

**Indicators of Compromise (IOCs):**

| Type | Value |
|---|---|
| Source IP | `203.0.1.X` |
| Target email | `admin@prabalurja.in` |
| Attack endpoint | `POST /forgot-password` |
| Anomaly signature | `Reset URL` domain ≠ `203.x.x.x` |
| Secondary exfil | Mail relay host `203.x.x.x:25` accessed from admin panel |

**Tactics, Techniques, and Procedures (TTPs):**

**Exploit Public-Facing Application (T1190)**
Adversary targeted the externally accessible employee portal, exploiting an application-level misconfiguration in the password reset flow to bypass authentication.

**Valid Accounts (T1078)**
By resetting the admin account password, the adversary obtained a legitimately issued session token — subsequent actions appear as normal authenticated behaviour to the application.

**Unsecured Credentials — Credentials in Files (T1552.001)**
The admin dashboard exposed internal service credentials (mail relay access details) to the compromised session — a secondary credential exposure from the initial compromise.

**Mitigation Recommendations:**
- Enforce `SERVER_NAME` configuration in all Flask applications.
- Implement application-layer WAF rules to detect Host header anomalies on sensitive endpoints.
- Deploy HTTPS across the entire v-Public segment.
- Implement role-based information hiding: admin dashboards should not surface network topology.
- Conduct quarterly source code review of all password reset and authentication flows.

---

## 5. Communication

**Internal Notification:**
- **SOC Lead:** Immediate — incident declared at `[TIME]`
- **IT Infrastructure Team:** Notified for mail relay hardening (secondary risk from exfiltrated relay IP)
- **CISO / IT Head:** Executive summary dispatched within 1 hour of detection
- **Legal / Compliance:** Notified — data classification review of admin dashboard content required

**External Notification:**
- **CERT-In:** Notification to be filed under IT Act 2000 / CERT-In notification obligations if PII was accessible via admin session.
- **NCIIPC:** Flagged for review given PUL's critical infrastructure classification.

**Update Frequency:** Every 2 hours until containment confirmed; daily thereafter until closure.

---

## 6. Additional Notes

The attacker did not require any privileged network position — the attack was fully executable from an unauthenticated HTTP client on the v-Public segment (`203.0.0.0/8`). This underscores the need for application-level controls that do not rely on network perimeter security as a compensating control.

---

## 7. POC (Screenshots)

> **[Attach: curl request with manipulated Host header and reflected token in response]**

> **[Attach: reset_requests.log entry showing attacker domain in Reset URL]**

> **[Attach: app.log entry showing successful admin login from attacker IP]**

> **[Attach: admin dashboard showing IT Infrastructure panel with mail relay details]**

---

## 8. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M01
