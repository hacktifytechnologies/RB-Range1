# Situation Report (SITREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** SITREP-IT01-M05
**Version:** 1.0
**Date:** [Date of Incident]
**Time:** [Time of Detection — IST]
**Incident ID:** GRIDFALL-RNG-IT01-M05

---

## 1. Incident Overview

**Description:**
- Unauthenticated Redis access on PUL application cache (`203.x.x.x:6379`) — no `requirepass` configured; `bind 0.0.0.0` exposes service to v-Public segment.
- Attacker enumerated all cache keys via `KEYS *` — identified `pul:config:ldap` and `pul:session:admin` as high-value targets.
- `pul:config:ldap` contains LDAP bind credential `cn=svc-deploy:D3pl0y@PUL2024` and LDAP host `203.x.x.x:389` for RNG-IT-02.
- Lateral movement to RNG-IT-02 directory service now fully enabled — this concludes the RNG-IT-01 intrusion chain.

**Severity Level:** `CRITICAL`
**Impact:** `SEVERE` — Full credential chain established M1→M5; pivot to RNG-IT-02 enabled.

**Affected Systems:**

| Machine | IP | Service | Impact |
|---|---|---|---|
| M5 — itgw-cache | `203.x.x.x` | Redis (TCP 6379) | All cache keys enumerated; LDAP credential exfiltrated |

---

## 2. Incident Details

**Detection Method:**
- `/var/log/pul-cache/redis.log` — external IP connection logged.
- Redis `MONITOR` output — `KEYS *`, `GET pul:config:ldap` from attacker IP.
- LDAP access log on `203.x.x.x` — unexpected bind from `svc-deploy` originating from attacker IP (secondary detection).

**Initial Detection Time:** `[Timestamp of first Redis connection log from attacker IP]`

**Attack Sequence:**
1. Attacker connects to `203.x.x.x:6379` — no authentication required, connection accepted.
2. `PING` returns `PONG` — confirms unauthenticated access.
3. `KEYS *` — all cache keys enumerated: `pul:session:admin`, `pul:config:ldap`, `pul:config:app`, `pul:queue:deploy`.
4. `GET pul:config:ldap` — JSON payload retrieved containing LDAP host, bind DN, and bind password.
5. `GET pul:session:admin` — admin session JSON retrieved (secondary confirmation of LDAP credential).
6. `ldapsearch` issued against `203.x.x.x:389` using `cn=svc-deploy` credential — successful LDAP bind confirms pivot.

---

## 3. Response Actions Taken

**Containment:**
- Redis `requirepass` enabled immediately; external access severed.
- `bind 0.0.0.0` replaced with `bind 127.0.0.1` — external access removed at service level.
- UFW rule added: TCP 6379 denied from all non-localhost sources.
- `pul:config:ldap` and `pul:session:admin` keys deleted from cache.
- Attacker source IP blocked at host firewall.

**Eradication:**
- Root cause patched: `bind`, `protected-mode`, and `requirepass` hardened in redis.conf.
- `KEYS`, `CONFIG`, and `FLUSHALL` commands renamed (disabled) via redis.conf.
- Application code audited — LDAP credential write-to-cache path identified and removed. Secrets manager integration planned.
- `svc-deploy` LDAP credential rotation request issued to RNG-IT-02 directory team.

**Recovery:**
- Application reconnected to Redis on localhost with new strong password.
- Redis ACLs (Redis 6 ACL module) implemented — application account has restricted command set.
- Full cache flush performed — all previous cached data cleared.
- LDAP credential rotation completed in RNG-IT-02 (confirmed by directory team).

**Lessons Learned:**
- Redis must never be exposed to untrusted networks without both authentication and network-layer access control.
- Application caches are not secret stores — credentials must reside only in dedicated secrets management systems.
- The complete five-stage intrusion chain (M1→M5) across RNG-IT-01 demonstrates the operational consequence of individual misconfigurations compounding: each stage leveraged the artifact of the previous.
- Defence-in-depth across all five stages would have halted the chain: HTTPS on M1 protects token transit; auth on M2 SMTP prevents spool access; JWT strict algorithms stop M3; SNMP v3 + restricted OIDs block M4; Redis auth + bind 127.0.0.1 closes M5.

---

## 4. Technical Analysis

**Evidence:**

| Artefact | Location | Relevance |
|---|---|---|
| Redis connection log | `/var/log/pul-cache/redis.log` | Confirms external unauthenticated connection |
| KEYS * command log | Redis MONITOR output | Enumerates attacker's key discovery |
| `pul:config:ldap` value | Redis key | Source of LDAP credential exposure |
| LDAP bind log | `203.x.x.x` access log | Secondary confirmation of successful pivot |

**TTPs:**

**Unsecured Credentials (T1552)**
LDAP service account credentials stored in plaintext as a Redis cache key value — accessible without authentication to any network-adjacent host.

**Data from Local System (T1005)**
Attacker collected operational data (LDAP configuration, deployment queue, application config) from the Redis cache — equivalent to reading an application's runtime configuration.

**Remote Services (T1021)**
Successful LDAP bind using harvested credential confirms lateral movement capability into RNG-IT-02 directory infrastructure.

**Mitigation Recommendations:**
- Enforce Redis Security Baseline: `bind 127.0.0.1`, `requirepass <32-char>`, `protected-mode yes`, rename dangerous commands.
- Implement network firewall: TCP 6379 restricted to application host IP only — never accessible from the general network segment.
- Adopt secrets management: HashiCorp Vault or AWS Secrets Manager for all service credentials. Application reads secrets at init time, never writes to cache.
- Redis 6 ACL: application account limited to `GET`, `SET`, `DEL` on specific key prefixes only — prohibit `KEYS *`, `CONFIG`, `DEBUG`, `MONITOR`.
- Implement data classification for cache keys: flag any key containing `pass`, `secret`, `token`, `credential` patterns for security review.

---

## 5. Communication

**Internal Notification:**
- **SOC Lead:** Immediate — full RNG-IT-01 chain complete; pivot into RNG-IT-02 in progress.
- **RNG-IT-02 Directory Team:** Critical — LDAP `svc-deploy` credential used by adversary; immediate rotation required.
- **CISO / IT Head:** Full executive briefing — 5-stage intrusion chain across Corporate Gateway segment concluded; RNG-IT-02 at risk.
- **CERT-In:** Mandatory notification — CII-adjacent LDAP directory service breach via 5-stage credential chain.
- **NCIIPC:** Advisory issued — critical infrastructure operations segment (IT-Ops zone) reachable via established pivot credential.

---

## 6. POC (Screenshots)

> **[Attach: redis-cli PING from attacker IP — PONG response]**
> **[Attach: KEYS * output showing all pul:* keys]**
> **[Attach: GET pul:config:ldap — JSON with bind_pass visible]**
> **[Attach: ldapsearch output confirming successful pivot bind to 203.x.x.x]**

---

## 7. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M05
