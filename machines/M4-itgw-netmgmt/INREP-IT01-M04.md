# Incident Notification Report (INREP)
**Classification:** RESTRICTED — Internal Use Only
**Report ID:** INREP-IT01-M04
**Version:** 1.0
**Date:** [Date of Detection]
**Time:** [Time of Detection — IST]

---

## 1. Current Situation

**Description:**
The PUL Network Management Host (`203.x.x.x:161/UDP`) is running SNMPv2c with the default community string `public` accessible from all source IPs. An adversary pivoting from M3 performed a full MIB walk and discovered private enterprise OID extensions (`.1.3.6.1.4.1.99999.*`) configured via snmpd `extend` directives. These extensions expose internal network segment information and a split Redis service account credential (`redis-svc-user:r3d1s-cache@PUL!2024`) along with the Redis cache host (`203.x.x.x:6379`). Lateral movement to M5 is assessed as in-progress.

**Threat Level:** `HIGH`

**Areas of Concern:**
- Default SNMP community string accessible from the entire v-Public segment.
- Credential material embedded in SNMP OID values — trivially extractable via `snmpwalk`.
- Redis cache host IP and port disclosed — direct pivot path to M5 enabled.

---

## 2. Threat Intelligence

**Sources:**
- `/var/log/syslog` — snmpd access entries.
- `/etc/snmp/snmpd.conf` — extend directives with embedded artefacts.

**Indicators of Compromise:**

| IOC Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Attack Vector | SNMPv2c walk, community string `public` |
| Targeted OID Space | `.1.3.6.1.4.1.99999` (private enterprise / extend MIB) |
| Exposed Credential | `redis-svc-user:r3d1s-cache@PUL!2024` |
| Exposed Cache Endpoint | `203.x.x.x:6379` |

**Log Entry Identified:**
```
snmpd: Connection from UDP: [203.0.1.X]:XXXXX
snmpd: GET .1.3.6.1.4.1.99999
```

---

## 3. Vulnerability Identification

**Vulnerability 1:** `rocommunity public default` — SNMP v2c community string `public` accessible from all source IPs. No authentication.
**Vulnerability 2:** `extend` directives exposing credential material as SNMP OID string values.
**Vulnerability 3:** SNMPv2c community strings transmitted in plaintext — susceptible to passive capture.

**Patch Status:** Pending. See `solve_blue.md`.

---

## 4. Security Operations

**Prevention Steps:**
- Replace `public` community string with a strong random value. Restrict access to management VLAN only.
- Remove all credential material from `extend` directives — SNMP OIDs must not contain credentials or sensitive topology data.
- Migrate to SNMPv3 with SHA authentication and AES privacy for all SNMP traffic.
- Implement UFW/iptables rule restricting UDP 161 to authorised monitoring host IPs only.

---

## 5. POC (Screenshots)

> **[Attach: snmpwalk output showing OIDs .1.3.6.1.4.1.99999.* with credential fragments]**
> **[Attach: grep of snmpd.conf showing extend directives with credential data]**
> **[Attach: assembled credential string from concatenated OID values]**

---

## 6. Submission

**Prepared By:** Blue Team — [Team Name]
**Reviewed By:** White Team / Exercise Controller
**Incident Reference:** GRIDFALL-RNG-IT01-M04
