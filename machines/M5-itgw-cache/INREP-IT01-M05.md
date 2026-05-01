# Incident Notification Report (INREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** INREP-IT01-M05
**Version:** 1.0
**Date:** [Date of Detection]
**Time:** [Time of Detection — IST]

---

## 1. Current Situation

**Description:**
The PUL application cache host (`203.x.x.x:6379`) is running Redis with no authentication (`requirepass` not configured) and is bound to all interfaces (`bind 0.0.0.0`). An adversary pivoting from M4 connected without credentials and enumerated all cache keys. The keys `pul:config:ldap` and `pul:session:admin` contain the `svc-deploy` LDAP service account credential (`D3pl0y@PUL2024`) and the LDAP host for RNG-IT-02 (`203.x.x.x:389`). Lateral movement into RNG-IT-02 is now enabled via this credential.

**Threat Level:** `CRITICAL`

**Areas of Concern:**
- Redis unauthenticated, world-accessible — any host on v-Public can read, write, or delete all cache keys.
- LDAP bind credential for the IT-Ops directory service stored in plaintext in a cache key — full credential chain M1→M5 terminated here.
- Pivot to RNG-IT-02 (`203.x.x.x/24`) is now trivially enabled.

---

## 2. Threat Intelligence

**Sources:**
- `/var/log/pul-cache/redis.log`
- Redis MONITOR output

**Indicators of Compromise:**

| IOC Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Attack Vector | Unauthenticated Redis connection from external IP |
| Commands Observed | `KEYS *`, `GET pul:config:ldap`, `GET pul:session:admin` |
| Compromised Credential | `cn=svc-deploy:D3pl0y@PUL2024` (LDAP bind) |
| Pivot Target | `203.x.x.x:389` (RNG-IT-02 LDAP) |

---

## 3. Vulnerability Identification

**Vulnerability 1:** Redis `bind 0.0.0.0` — listens on all interfaces including externally reachable ones.
**Vulnerability 2:** `requirepass` not configured — zero authentication required.
**Vulnerability 3:** LDAP service account credential stored in a Redis key — credentials in cache constitute a plaintext secret exposure.

**Patch Status:** Pending. See `solve_blue.md`.

---

## 4. Security Operations

**Prevention Steps:**
- Set `bind 127.0.0.1` in redis.conf — never expose Redis to non-localhost interfaces without a firewall.
- Set a strong `requirepass` (minimum 32 characters).
- Never store credentials in application cache — use a dedicated secrets manager.
- Implement Redis ACLs (Redis 6+) for granular command-level access control.
- Firewall rule: TCP 6379 whitelisted to application server IP only.

---

## 5. POC (Screenshots)

> **[Attach: redis-cli PING from attacker IP — PONG response confirming no-auth]**
> **[Attach: KEYS * output showing all pul:* keys]**
> **[Attach: GET pul:config:ldap output with bind_pass visible]**
> **[Attach: ldapsearch confirmation of working pivot credential against 203.x.x.x]**

---

## 6. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M05
