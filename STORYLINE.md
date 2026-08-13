# OPERATION GRIDFALL - Storyline
**Classification:** EXERCISE ONLY - Not for operational use
**Version:** 1.0
**Range:** RNG-IT-01 · Corporate Gateway

---

## Threat Actor: APT38

APT38 is an Advanced Persistent Threat (APT) composite modelled on documented north korean state-nexus threat actor tradecraft. The actor targets Indian critical information infrastructure (CII) - specifically power utilities, grid operations centres, and associated IT/OT supply chains. APT38 is characterised by patient, multi-stage intrusions with a preference for Living-off-the-Land (LotL) techniques, legitimate tool abuse, and credential-chain exploitation over noisy exploit frameworks.

**Attribution Profile (Exercise):**
- Likely state-sponsored
- Long dwell time (weeks to months before detection)
- Focus: grid operations disruption, SCADA pre-positioning, exfiltration of operational data
- TTPs overlap with APT36 (Transparent Tribe) initial access patterns and TAG-38/RedEcho post-compromise lateral movement

---

## Target Organisation: Prabal Urja Limited (PUL)

Prabal Urja Limited is a fictional Indian power transmission and grid operations company analogous to NTPC and POSOCO combined. PUL operates the NEXUS-IT network - a multi-zone IT infrastructure spanning:

- **v-Public** (`203.0.0.0/8`) - Internet-facing corporate gateway services
- **v-DMZ** (`11.0.0.0/8`) - Development, CI/CD, and integration zone
- **v-Private** (`193.0.0.0/8`) - Internal OT/ICS-adjacent operations networks

PUL's corporate IT is managed from a centralised data centre with regional substations connected via MPLS. The NEXUS-IT platform hosts employee services, internal tooling, CI/CD pipelines, and service integrations bridging IT and OT zones.

---

## Scenario Narrative

### Phase 1 - Initial Access (RNG-IT-01)

APT38 has identified Prabal Urja Limited as a high-value target. Intelligence indicates PUL recently expanded its digital estate with a new Employee Self-Service Portal and an internal Staff Authentication Gateway - both accessible from the v-Public segment.

APT38 operators initiate reconnaissance against the Corporate Gateway (`203.x.x.x/24`). They identify five internet-reachable services and begin a systematic, credential-chaining intrusion:

**M1 - Employee Portal:** An operator identifies a password reset mechanism on the employee self-service portal. By manipulating an HTTP header in the reset request, the operator is able to intercept the admin account's reset token without controlling any external infrastructure. Admin dashboard access reveals an internal mail relay.

**M2 - Mail Relay:** The mail relay is configured as an open relay with no SMTP authentication and exposes user mailboxes through filesystem permission misconfigurations. A pre-planted internal email in the SOC analyst mailbox contains a non-standard header embedding an encoded service account credential for the Staff Authentication Gateway.

**M3 - Authentication Gateway:** Using the harvested service account credential, the operator authenticates to the Staff Authentication Gateway and receives a signed session token. The token's signing mechanism contains a critical flaw - by modifying the algorithm declaration within the token, the operator forges an administrative token without knowledge of the server's signing secret. Administrative access discloses the internal SNMP management host.

**M4 - Network Management Host:** The SNMP service runs with a default community string and exposes custom management extensions containing split credential fragments for the application cache layer. The operator assembles the complete cache access credential and discovers the cache host endpoint.

**M5 - Application Cache:** Connecting to the cache service without authentication, the operator enumerates all stored application data. A configuration key contains the LDAP service account credential for the IT-Ops internal zone - completing the Corporate Gateway intrusion and enabling lateral movement into `RNG-IT-02` (`203.x.x.x/24`).

---

# Network Diagram — RNG-IT-01 · Corporate Gateway
## OPERATION GRIDFALL | Prabal Urja Limited — NEXUS-IT Platform

---

```
                         INTERNET / ATTACKER
                               │
                    ┌──────────▼──────────┐
                    │    v-Public Network   │
                    │    203.0.0.0/8        │
                    │    (External-facing)  │
                    └──────────┬───────────┘
                               │
              ┌────────────────┼────────────────────────────┐
              │                │                            │
              ▼                ▼                            ▼
   ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐
   │  M1-itgw-webportal│  │M2-itgw-mailrelay │  │  M3-itgw-sso       │
   │  203.x.x.x:8080  │  │  203.x.x.x:25   │  │  203.x.x.x:8443   │
   │  Flask Portal     │  │  Postfix SMTP    │  │  Flask JWT Gateway │
   │  [Host Hdr Inject]│  │  [Open Relay]    │  │  [alg:none JWT]    │
   └──────────┬────────┘  └────────┬─────────┘  └─────────┬──────────┘
              │                    │                       │
              │ Pivot: mail relay  │ Pivot: X-Internal     │ Pivot: SNMP host
              │ 203.x.x.x:25      │ -Auth-Token decoded   │ 203.x.x.x:161
              │                    │                       │
              └──────────┐         └───────────┐           │
                         ▼                     ▼           ▼
              ┌─────────────────────────────────────────────────────┐
              │              RNG-IT-01 Subnet: 203.x.x.x/24         │
              │                                                     │
              │  ┌──────────────────┐      ┌──────────────────┐    │
              │  │ M4-itgw-netmgmt  │      │  M5-itgw-cache   │    │
              │  │ 203.x.x.x:161   │      │  203.x.x.x:6379 │    │
              │  │ snmpd v2c        │─────▶│  Redis (no-auth) │    │
              │  │ [Weak community] │      │  [No requirepass] │    │
              │  │ OID credential   │      │  pul:config:ldap  │    │
              │  └──────────────────┘      └─────────┬────────┘    │
              │  Pivot: Redis host +                  │             │
              │  credential fragments                 │             │
              └──────────────────────────────────────┼─────────────┘
                                                     │
                                          Pivot: LDAP bind cred
                                          cn=svc-deploy
                                          D3pl0y@PUL2024
                                                     │
                    ┌────────────────────────────────▼────────────────┐
                    │              v-Public Network                    │
                    │              (Gateway to RNG-IT-02)             │
                    │              203.x.x.x/24 — IT-Ops Zone         │
                    │              LDAP: 203.x.x.x:389               │
                    │              [Next Range: nexus-itops-range]    │
                    └──────────────────────────────────────────────────┘
```

---

## Machine Summary Table

| ID | Hostname | IP Address | Port | Protocol | Service | Vulnerability |
|----|----------|-----------|------|----------|---------|---------------|
| M1 | itgw-webportal | `203.x.x.x` | 8080 | HTTP | Flask Employee Portal | Host Header Injection — Password Reset |
| M2 | itgw-mailrelay | `203.x.x.x` | 25 | SMTP | Postfix Mail Relay | Open Relay + World-Readable Spool |
| M3 | itgw-sso | `203.x.x.x` | 8443 | HTTP | Flask JWT Auth Gateway | JWT Algorithm Confusion (alg: none) |
| M4 | itgw-netmgmt | `203.x.x.x` | 161 | UDP/SNMP | snmpd v2c Agent | Default Community + Credential OIDs |
| M5 | itgw-cache | `203.x.x.x` | 6379 | TCP | Redis Cache | No Authentication + Creds in Keys |

---

## Honeytrap Ports (per machine — do not use for challenge)

| Machine | Honeytrap Port | Protocol | Description |
|---------|---------------|----------|-------------|
| M1 | 8888 | TCP | Fake Admin Backup Console |
| M2 | 9025 | TCP | Fake SMTP Submission |
| M3 | 9389 | TCP | Fake LDAP Endpoint |
| M4 | 9161 | UDP | Fake SNMP Trap Receiver |
| M5 | 6380 | TCP | Fake Redis Secondary |

---

## Credential Chain

```
[Unauthenticated]
     │
     ▼ Host Header Injection
  admin@prabalurja.in session (M1)
     │
     ▼ Admin Dashboard → Mail Relay IP
  203.x.x.x:25 SMTP (M2)
     │
     ▼ X-Internal-Auth-Token decoded
  svc-deploy-sso : SSO@Prabal!2024 (M3)
     │
     ▼ JWT alg:none → admin panel
  203.x.x.x:161 SNMP (M4)
     │
     ▼ OID walk → credential fragments assembled
  redis-svc-user : r3d1s-cache@PUL!2024 + 203.x.x.x:6379 (M5)
     │
     ▼ Redis KEYS → pul:config:ldap
  cn=svc-deploy : D3pl0y@PUL2024 → 203.x.x.x:389
     │
     ▼ PIVOT → RNG-IT-02 (nexus-itops-range)
```

---

## Network Topology Notes

- All machines are in the same OpenStack tenant network `v-Public` (`203.0.0.0/8`).
- RNG-IT-01 machines communicate with each other on `203.x.x.x/24`.
- Pivot target (RNG-IT-02) is on a separate OpenStack network `v-Public` at `203.x.x.x/24`.
- Route from `203.x.x.x/24` to `203.x.x.x/24` is via gateway `203.x.x.x`.
- No firewall between v-Public subnets by default — participants must pivot using credentials only.


## Rules of Engagement

- All activity is confined to the `203.x.x.x/24` subnet for RNG-IT-01.
- No persistence mechanisms beyond the challenge scope.
- No denial-of-service or data destruction.
- Report any unintended vulnerabilities or environment issues to White Team immediately.
- All exercise actions are logged by the range platform.

---

*OPERATION GRIDFALL is a fictional exercise. All organisations, individuals, IP addresses, credentials, and infrastructure described are fabricated for training purposes only.*
