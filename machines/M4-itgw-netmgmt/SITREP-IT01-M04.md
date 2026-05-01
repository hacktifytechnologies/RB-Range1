# Situation Report (SITREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** SITREP-IT01-M04
**Version:** 1.0
**Date:** [Date of Incident]
**Time:** [Time of Detection — IST]
**Incident ID:** GRIDFALL-RNG-IT01-M04

---

## 1. Incident Overview

**Description:**
- SNMPv2c enumeration on PUL Network Management Host (`203.x.x.x:161/UDP`) — attacker used default community string `public` to perform a full MIB walk.
- Private enterprise OIDs (`.1.3.6.1.4.1.99999.*`) returned via snmpd `extend` directives containing split credential fragments and cache host details.
- Assembled credential: `redis-svc-user:r3d1s-cache@PUL!2024` and Redis host `203.x.x.x:6379` extracted.
- Pivot to M5 (itgw-cache) in progress.

**Severity Level:** `HIGH`
**Impact:** `SEVERE` — Redis service account credential and cache endpoint fully disclosed; M5 pivot imminent.

**Affected Systems:**

| Machine | IP | Service | Impact |
|---|---|---|---|
| M4 — itgw-netmgmt | `203.x.x.x` | snmpd (UDP 161) | Community string enumerated; credential OIDs harvested |

---

## 2. Incident Details

**Detection Method:**
- Syslog review — repeated SNMP connection entries from external attacker IP.
- Audit of `/etc/snmp/snmpd.conf` — `extend` directives found containing credential fragments.

**Initial Detection Time:** `[Timestamp of first snmpd connection log from attacker IP]`

**Attack Sequence:**
1. Attacker discovers SNMP on UDP 161 from M3 admin panel disclosure.
2. `snmpwalk -v2c -c public 203.x.x.x system` — community string `public` confirmed valid.
3. `snmpwalk -v2c -c public 203.x.x.x .1.3.6.1.4.1.8072.1.3.2` — extend MIB walked.
4. OID values returned: `redis-svc-user:r3d` (part 1), `1s-cache@PUL!2024` (part 2), cache host `203.x.x.x:6379`.
5. Credential assembled by concatenation of part 1 + part 2.
6. Redis endpoint documented — M5 attack initiated.

---

## 3. Response Actions Taken

**Containment:**
- `rocommunity public default` replaced with `rocommunity <new_string> 127.0.0.1` — external access removed.
- Credential OID extend directives removed from snmpd.conf.
- `snmpd` reloaded.
- Attacker source IP blocked at UFW for UDP 161.

**Eradication:**
- Community string rotated to strong random value.
- SNMPv3 migration plan initiated.
- Redis credential rotation notification sent to M5 team.
- All extend directives audited — no additional credential material found.

**Recovery:**
- Monitoring host updated with new community string.
- UFW rule added: UDP 161 restricted to monitoring host IP only.
- Scheduled SNMPv3 migration within 30 days.

**Lessons Learned:**
- Default SNMP community strings must be changed before deployment. `public` and `private` are universally known and should never be used in production.
- SNMP OIDs must never contain credential material. Secrets belong in a secrets manager, not in monitoring agent configurations.
- SNMPv2c community strings are transmitted in cleartext — any passive observer on the segment can capture them. SNMPv3 with encryption is mandatory for production use.
- The multi-stage intrusion chain (M1 → M2 → M3 → M4) demonstrates why defence-in-depth is critical — each stage leveraged artifacts from the previous to advance further into the network.

---

## 4. Technical Analysis

**Evidence:**

| Artefact | Location | Relevance |
|---|---|---|
| SNMP access log | `/var/log/syslog` | Confirms external MIB walk |
| snmpd.conf | `/etc/snmp/snmpd.conf` | Source of credential embed |
| OID values | `.1.3.6.1.4.1.99999.*` | Credential fragments in SNMP tree |
| Assembled credential | `redis-svc-user:r3d1s-cache@PUL!2024` | Pivot artifact for M5 |

**TTPs:**

**Network Service Discovery (T1046)**
Adversary used `snmpwalk` to enumerate the SNMP service and traverse the MIB tree, identifying non-standard OID extensions planted in the private enterprise subtree.

**Data from Configuration Repository: Network Device Configuration (T1602.002)**
SNMP is used by network management systems to retrieve device configuration. The adversary leveraged this protocol to extract credential material stored in misconfigured `extend` directives.

**Unsecured Credentials (T1552)**
Credential fragments stored in plaintext in snmpd configuration and exposed via OID query — trivially assembled by concatenation.

**Mitigation Recommendations:**
- Replace SNMPv2c with SNMPv3 (authentication + privacy) across the entire estate.
- Enforce network-level access control: UDP 161 whitelisted to monitoring host only.
- Add SNMP MIB content review to change management — reject any extend directive with sensitive output.
- Conduct quarterly SNMP community string rotation.

---

## 5. Communication

**Internal Notification:**
- **SOC Lead:** Immediate — credential chain now extends to cache/data layer.
- **Cache/Redis Team:** Urgent — `redis-svc-user` credential rotation required before M5 exploitation.
- **CISO:** Full chain M1→M4 briefed — network management layer reached.
- **CERT-In:** Notification to be filed — CII-adjacent network management infrastructure compromised.

---

## 6. POC (Screenshots)

> **[Attach: snmpwalk output showing OIDs .1.3.6.1.4.1.99999.* with credential values]**
> **[Attach: snmpd.conf excerpt showing extend directives]**
> **[Attach: Credential assembly — concatenation of pul-cred-part1 and pul-cred-part2]**

---

## 7. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M04
