# Incident Notification Report (INREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** INREP-IT01-M03
**Version:** 1.0
**Date:** [Date of Detection]
**Time:** [Time of Detection — IST]

---

## 1. Current Situation

**Description:**
The PUL Staff Authentication Gateway (`203.x.x.x:8443`) has been exploited via a JWT algorithm confusion attack. The attacker — using the `svc-deploy-sso` credential harvested from M2 — authenticated to the gateway, received a legitimately signed HS256 JWT, then forged a replacement token with `alg: none` and `role: admin` in the payload. The server accepted the unsigned forged token, granting admin-level access. The admin portal disclosed the internal SNMP management host (`203.x.x.x:161`), enabling the attacker to pivot to M4.

**Threat Level:** `CRITICAL`

**Areas of Concern:**
- JWT algorithm confusion allows complete authentication bypass for any registered account.
- Admin-level infrastructure panel accessed — SNMP host and version disclosed.
- The credential chain (M1 → M2 → M3) demonstrates a multi-stage, interdependent intrusion progressing across the Corporate Gateway segment.

---

## 2. Threat Intelligence

**Sources:**
- `/var/log/pul-sso/sso.log`

**Indicators of Compromise:**

| IOC Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Forged Token Indicator | JWT header `alg` field = `"none"` |
| Log Signature | `ALG_NONE_ACCEPTED` in sso.log |
| Escalated Account | `svc-deploy-sso` → `role: admin` |
| Data Exfiltrated | SNMP host `203.x.x.x:161` |

**Log Entry Identified:**
```
[WARNING] ALG_NONE_ACCEPTED | sub=svc-deploy-sso role=admin from=203.0.1.X
```

---

## 3. Vulnerability Identification

**Vulnerability:** JWT Algorithm Confusion — the `decode_jwt_vulnerable()` function accepts `alg: none` without signature verification. Any client can forge an arbitrary payload with any role.

**CWE Reference:** CWE-347 (Improper Verification of Cryptographic Signature)

**Patch Status:** Pending — use `jwt.decode(..., algorithms=['HS256'])` explicitly. See `solve_blue.md`.

---

## 4. Security Operations

**Prevention Steps:**
- Always pass an explicit `algorithms=` whitelist to PyJWT's `decode()`.
- Never implement custom JWT parsing — use the library's built-in verification.
- Reject any token whose header `alg` is not in the allowed set.
- Implement short-lived tokens (15 min) with refresh for privileged service accounts.

---

## 5. POC (Screenshots)

> **[Attach: Token decode output showing original `role: analyst` payload]**
> **[Attach: Forged token construction commands — header + payload + empty signature]**
> **[Attach: curl response showing admin portal with SNMP host details]**
> **[Attach: sso.log showing ALG_NONE_ACCEPTED entry]**

---

## 6. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M03
