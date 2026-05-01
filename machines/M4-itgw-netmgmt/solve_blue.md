# solve_blue.md — M4 · itgw-netmgmt
## Blue Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M4 — Network Management Host
**Vulnerability:** SNMP v2c Weak Community String + Credential Material in Custom OIDs
**MITRE ATT&CK:** T1046 · T1552
**Kill Chain Stage:** Detection → Containment → Eradication → Recovery

---

## Detection

### 1 — SNMP Access Log Review

SNMP queries are logged to syslog on Ubuntu 22.04:
```bash
grep -i snmp /var/log/syslog | tail -50
```

Or via journald:
```bash
journalctl -u snmpd --since "1 hour ago" | grep -E "GET|SET|WALK"
```

**Anomalous pattern — full MIB walk from external IP:**
```
snmpd[XXXX]: 203.0.1.X: GET .1.3.6.1.4.1.99999
snmpd[XXXX]: Connection from UDP: [203.0.1.X]:XXXXX
```

Any external IP issuing SNMP queries against the private enterprise OID space (`.1.3.6.1.4.1.99999`) is a confirmed reconnaissance/harvest event.

### 2 — Community String Audit

```bash
grep "rocommunity\|rwcommunity\|com2sec" /etc/snmp/snmpd.conf
```

**Misconfiguration detected:**
```
rocommunity public  default
```

`default` means any source IP — community string `public` is world-accessible.

### 3 — Credential Material Audit in snmpd.conf

```bash
grep "extend" /etc/snmp/snmpd.conf
```

**Finding:** `extend` directives returning credential fragments in OID values. This is a critical misconfiguration — SNMP OID values should never contain credential material.

---

## Containment

### 1 — Restrict SNMP Access Immediately
```bash
# Limit SNMP to localhost / management VLAN only
postconf does not apply here — edit snmpd.conf:
sed -i 's/rocommunity public  default/rocommunity public  127.0.0.1/' /etc/snmp/snmpd.conf
systemctl restart snmpd
```

### 2 — Remove Credential OIDs
```bash
# Remove all extend directives containing credential material
sed -i '/extend.*pul-cred/d' /etc/snmp/snmpd.conf
sed -i '/extend.*pul-cache/d' /etc/snmp/snmpd.conf
sed -i '/extend.*pul-segment/d' /etc/snmp/snmpd.conf
systemctl restart snmpd
```

### 3 — Block Attacker Source IP
```bash
ufw deny from <ATTACKER_IP> to any port 161 proto udp comment "M4 SNMP recon"
```

### 4 — Rotate Compromised Redis Credential
The credential `redis-svc-user:r3d1s-cache@PUL!2024` exposed via SNMP OIDs must be treated as fully compromised. Notify the M5/cache team immediately.

---

## Eradication

**1. Rename / rotate the community string:**
```bash
# Replace 'public' with a strong random community string
NEW_COMMUNITY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
sed -i "s/rocommunity public/rocommunity ${NEW_COMMUNITY}/" /etc/snmp/snmpd.conf
echo "New SNMP community: ${NEW_COMMUNITY}"
systemctl restart snmpd
```

**2. Migrate to SNMPv3 (no community strings):**
```bash
# Add SNMPv3 user (authentication + privacy)
net-snmp-create-v3-user -ro -A "AuthPass@2024" -a SHA \
    -X "PrivPass@2024" -x AES snmpv3user
systemctl restart snmpd
```

**3. Remove all credential material from SNMP OIDs:**
Audit ALL `extend` directives for any output that could contain IP addresses, credentials, or internal topology. SNMP should only expose approved monitoring metrics.

**4. Implement SNMP access control:**
```bash
# Restrict to management network only (example: 10.0.0.0/8)
postconf -e ... # not applicable — edit snmpd.conf directly:
# com2sec readonly 10.0.0.0/8 <strong_community>
# group   MyROGroup v2c readonly
# access  MyROGroup ""    any noauth prefix all none none
```

---

## Recovery
- Rotate Redis credential on M5 immediately.
- Audit all other `extend` directives across the estate for credential leakage.
- Implement network-level SNMP access control (firewall whitelist: only monitoring system IP to UDP 161).
- Migrate SNMP infrastructure to v3 with AES encryption and SHA authentication.
- Add SNMP MIB review to the change management process — any new `extend` directive requires security approval.

---

## IOCs

| Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Attack Vector | SNMPv2c walk with community `public` from external IP |
| Compromised OIDs | `.1.3.6.1.4.1.99999.{1,2,3,4}` |
| Exposed Credential | `redis-svc-user:r3d1s-cache@PUL!2024` |
| Exposed Endpoint | `203.x.x.x:6379` (Redis cache host) |
| Config File | `/etc/snmp/snmpd.conf` |
