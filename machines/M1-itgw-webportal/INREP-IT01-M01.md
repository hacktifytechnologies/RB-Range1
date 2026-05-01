# Incident Notification Report (INREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** INREP-IT01-M01
**Version:** 1.0
**Date:** [Date of Detection]
**Time:** [Time of Detection — IST]

---

## 1. Current Situation

**Description:**
The Prabal Urja Limited Employee Self-Service Portal (M1 — `203.x.x.x:8080`) is under active exploitation. An adversary has abused an HTTP Host Header Injection vulnerability in the password reset mechanism to redirect the admin account's reset token to an attacker-controlled domain. The attacker subsequently used the captured token to reset the admin password and gain authenticated access to the administrative dashboard. Internal IT infrastructure details — specifically the mail relay host (`203.x.x.x:25`) — have been exposed to the attacker via the admin panel.

**Threat Level:** `HIGH`

**Areas of Concern:**
- The `admin@prabalurja.in` account has been fully compromised via credential reset.
- The admin dashboard exposed internal mail relay infrastructure to the attacker.
- Lateral movement to the internal mail relay (M2) is assessed as imminent or already in progress.
- No HTTPS is in place — tokens may be interceptable in transit on the v-Public segment.

---

## 2. Threat Intelligence

**Sources:**
- Application reset log: `/var/log/pul-portal/reset_requests.log`
- Application event log: `/var/log/pul-portal/app.log`

**Indicators of Compromise (IOCs):**

| IOC Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Target Account | `admin@prabalurja.in` |
| Attack Vector | `POST /forgot-password` with manipulated `Host` header |
| Anomalous Log Entry | Reset URL domain does not match server address `203.x.x.x` |

**Log Entry Identified:**
```
[2024-11-15T09:43:12.334211] RESET REQUEST
  Recipient : admin@prabalurja.in
  Reset URL : http://attacker.com/reset-password?token=<TOKEN>
  Source IP : 203.0.1.X
```

**Attribution Context:**
This technique is consistent with documented KAAL CHAKRA (APT36/Transparent Tribe composite) initial access tradecraft targeting Indian government-adjacent digital estates. Host Header Injection in password reset flows has been observed as a preparatory step ahead of SMTP relay abuse and credential harvesting campaigns.

---

## 3. Vulnerability Identification

**Vulnerability:**
HTTP Host Header Injection in the `/forgot-password` endpoint. The Flask application constructs the password reset URL using the `Host` header from the incoming request without validation:

```python
# Vulnerable code
host = request.headers.get('Host', request.host)
reset_url = f"http://{host}/reset-password?token={token}"
```

The constructed URL — including the token — is reflected in the HTTP response, allowing an unauthenticated attacker to capture valid reset tokens for any registered account.

**Patch Status:** Pending — see eradication steps in `solve_blue.md`.

**CWE Reference:** CWE-640 (Weak Password Recovery Mechanism for Forgotten Password)

---

## 4. Security Operations

**Prevention Steps:**
- Hardcode the server's canonical hostname in application config — never derive it from request headers.
- Implement `SERVER_NAME` in Flask: `app.config['SERVER_NAME'] = '203.x.x.x:8080'`.
- Rate-limit the `/forgot-password` endpoint (max 3 requests/IP/10 min).
- Implement HTTPS — prevent token interception on the v-Public network segment.
- Add Web Application Firewall rule: block requests to `/forgot-password` where `Host` header does not match the configured server address.
- Enforce MFA on all `admin`-role accounts.

---

## 5. Additional Notes

The admin dashboard exposes raw infrastructure details (mail relay host, port, auth configuration) to any authenticated admin-role user. This constitutes a secondary finding — sensitive internal service topology should not be exposed in the UI without an additional need-to-know check.

---

## 6. POC (Screenshots)

> **[Attach screenshot of the malicious curl request showing `Host: attacker.com` in headers]**

> **[Attach screenshot of the HTTP response showing the reflected reset URL with attacker domain]**

> **[Attach screenshot of the admin dashboard showing the mail relay infrastructure panel]**

---

## 7. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M01
