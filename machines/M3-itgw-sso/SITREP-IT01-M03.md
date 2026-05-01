# Situation Report (SITREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** SITREP-IT01-M03
**Version:** 1.0
**Date:** [Date of Incident]
**Time:** [Time of Detection — IST]
**Incident ID:** GRIDFALL-RNG-IT01-M03

---

## 1. Incident Overview

**Description:**
- JWT Algorithm Confusion exploit on PUL Staff Authentication Gateway (`203.x.x.x:8443`).
- Attacker authenticated using `svc-deploy-sso` credential (harvested from M2 mail spool).
- Issued HS256 JWT with `role: analyst` decoded by attacker.
- Forged replacement JWT with `alg: none` and `role: admin` — server accepted without signature verification.
- Admin portal rendered — SNMP management host `203.x.x.x:161` disclosed.
- Pivot to M4 (itgw-netmgmt) in progress.

**Severity Level:** `CRITICAL`
**Impact:** `SEVERE` — Authentication completely bypassed for admin role; SNMP infra pivot artifact exfiltrated.

**Affected Systems:**

| Machine | IP | Service | Impact |
|---|---|---|---|
| M3 — itgw-sso | `203.x.x.x` | Flask JWT Gateway (port 8443) | Auth bypass via alg:none; admin panel accessed |

---

## 2. Incident Details

**Detection Method:**
- SSO log (`/var/log/pul-sso/sso.log`) reviewed — `ALG_NONE_ACCEPTED` warning entry identified.
- Analyst role `svc-deploy-sso` appearing with `role=admin` in portal access log — role escalation detected.

**Initial Detection Time:** `[Timestamp of ALG_NONE_ACCEPTED log entry]`

**Attack Sequence:**
1. Attacker POSTs `/login` with `svc-deploy-sso:SSO@Prabal!2024` — issued legitimate HS256 JWT with `role: analyst`.
2. Attacker base64URL-decodes JWT header and payload — reads current role.
3. Attacker constructs forged header: `{"alg":"none","typ":"JWT"}`.
4. Attacker constructs forged payload: `{"sub":"svc-deploy-sso","role":"admin","iat":...,"exp":9999999999}`.
5. Attacker assembles `<forged_header>.<forged_payload>.` (empty signature).
6. Attacker submits forged token in `pul_staff_token` cookie.
7. Server's `decode_jwt_vulnerable()` reads `alg: none` — skips signature verification — decodes payload.
8. `role: admin` rendered in portal — SNMP host `203.x.x.x:161` displayed.

---

## 3. Response Actions Taken

**Containment:**
- JWT secret rotated — all existing signed tokens invalidated.
- Service restarted — active sessions cleared.
- Attacker source IP blocked at host firewall.
- Alert rule added: flag any `ALG_NONE_ACCEPTED` log entry for immediate SOC response.

**Eradication:**
- Root cause patched: `decode_jwt_vulnerable()` replaced with `jwt.decode(..., algorithms=['HS256'])` — explicit algorithm whitelist enforced.
- Forged token acceptance confirmed blocked post-patch via re-test.
- Code review initiated for all other JWT decode calls across the PUL application estate.

**Recovery:**
- `svc-deploy-sso` credential rotated (chain-compromised since M2).
- WAF rule deployed: reject requests with `pul_staff_token` cookie whose header decodes to `alg: none`.
- Token expiry reduced to 15 minutes for all service accounts.

**Lessons Learned:**
- JWT algorithm confusion is a widely documented vulnerability — libraries must be used with explicit `algorithms=` parameter at all times.
- Never implement custom JWT parsing — library-provided `decode()` with a strict whitelist is the only safe approach.
- Service accounts with access to sensitive admin panels must use short-lived tokens and additional IP binding.
- The credential chain spanning M1 → M2 → M3 demonstrates how a single initial access point (Host Header Injection) can cascade to critical infrastructure disclosure. Each link must be independently hardened.

---

## 4. Technical Analysis

**Evidence:**

| Artefact | Location | Relevance |
|---|---|---|
| ALG_NONE log entry | `/var/log/pul-sso/sso.log` | Confirms algorithm confusion exploit |
| Role escalation log | `/var/log/pul-sso/sso.log` | `svc-deploy-sso` shown as `role=admin` |
| Forged token | Attacker's curl command | Demonstrates unsigned admin JWT |
| Admin panel screenshot | POC section | Confirms SNMP host disclosure |

**TTPs:**

**Forge Web Credentials (T1606)**
Adversary manipulated the JWT structure to set the algorithm to `none`, bypassing HMAC signature verification and asserting an elevated role without possessing the server's signing secret.

**Valid Accounts (T1078)**
The initial login used legitimately harvested credentials (`svc-deploy-sso`). Subsequent token forgery extended access beyond the account's authorised privilege level.

**System Information Discovery (T1082)**
The admin infrastructure panel was surveyed to extract internal network management service details (SNMP host, port, version).

**Mitigation Recommendations:**
- Enforce `algorithms=['HS256']` in all `jwt.decode()` calls — never allow dynamic algorithm selection from the token header.
- Implement short-lived tokens (≤15 min) with server-side token revocation lists for privileged accounts.
- Add mutual TLS between service accounts and the SSO gateway for stronger identity assurance.
- Integrate token validation into a centralised API gateway with WAF-level JWT inspection.

---

## 5. Communication

**Internal Notification:**
- **SOC Lead:** Immediate — critical auth bypass declared.
- **SNMP/Network Team:** Urgent — SNMP management host `203.x.x.x` must be hardened immediately (M4 at risk).
- **CISO:** Updated — intrusion chain now spans M1 → M2 → M3, approaching network management layer.
- **CERT-In:** Notification to be filed — admin-level authentication bypass on a CII-adjacent system.

---

## 6. POC (Screenshots)

> **[Attach: curl login response with JWT cookie set]**
> **[Attach: base64 decode of original JWT header and payload]**
> **[Attach: forged token construction — shell commands]**
> **[Attach: portal response showing admin role and SNMP panel]**
> **[Attach: sso.log — ALG_NONE_ACCEPTED warning line]**

---

## 7. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M03
