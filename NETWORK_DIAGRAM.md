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
