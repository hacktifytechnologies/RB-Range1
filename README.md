# Red Vs Blue - Range 1
## RNG-IT-01 · Corporate Gateway | OPERATION GRIDFALL
**Prabal Urja Limited - NEXUS-IT Purple Team Exercise**

---

## Overview

This repository contains the complete build artefacts for **RNG-IT-01**, the first range in the OPERATION GRIDFALL purple team exercise series. The range simulates the Corporate Gateway segment (`203.x.x.x/24`) of the Prabal Urja Limited (PUL) NEXUS-IT platform.

Five machines are configured with independent, chained vulnerabilities. Participants must exploit them in sequence, passing credential artefacts from each machine to the next.

---

## Directory Structure

```
nexus-itgw-range/
├── STORYLINE.md              # Threat actor narrative and exercise context
├── NETWORK_DIAGRAM.md        # Network topology and credential chain
├── README.md                 # This file - setup guide
├── github_push.sh            # GitHub push helper script
├── AssessmentQuestions.md    # Participant assessment questions (5 per machine)
├── Honeytraps/               # Decoy listener scripts (one per machine)
│   ├── M1-decoy-itgw-webportal.sh
│   ├── M2-decoy-itgw-mailrelay.sh
│   ├── M3-decoy-itgw-sso.sh
│   ├── M4-decoy-itgw-netmgmt.sh
│   └── M5-decoy-itgw-cache.sh
├── machines/
│   ├── M1-itgw-webportal/   # Flask Portal - Host Header Injection
│   │   ├── app/             # Flask application code + templates
│   │   ├── setup.sh         # Challenge setup (no internet required)
│   │   ├── deps.sh          # Dependency installer (internet required)
│   │   ├── solve_red.md     # Red team solution walkthrough
│   │   ├── solve_blue.md    # Blue team detection + remediation
│   │   ├── INREP-IT01-M01.md
│   │   ├── SITREP-IT01-M01.md
│   │   └── RED-REPORT-IT01-M01.md
│   ├── M2-itgw-mailrelay/   # Postfix - SMTP Open Relay
│   ├── M3-itgw-sso/         # Flask JWT Gateway - Algorithm Confusion
│   ├── M4-itgw-netmgmt/     # snmpd - Default Community String
│   └── M5-itgw-cache/       # Redis - No-Auth Exposure
└── ttps/
    ├── red_01_itgw-webportal_setup.yml
    ├── red_02_itgw-mailrelay_setup.yml
    ├── red_03_itgw-sso_setup.yml
    ├── red_04_itgw-netmgmt_setup.yml
    └── red_05_itgw-cache_setup.yml
```

---

## Prerequisites

- **Platform:** OpenStack (or any hypervisor - VirtualBox, VMware, KVM)
- **OS:** Ubuntu 22.04 LTS (fresh minimal install per machine)
- **Network:** Each machine assigned a static IP in `203.x.x.x/24`
- **Internet access:** Required **only** during `deps.sh` phase (before snapshot)

---

## Setup Workflow

The setup follows a strict **two-phase** workflow:

### Phase 1 - Dependency Installation (Internet Required)

Run `deps.sh` on each freshly provisioned VM. This installs all OS packages and Python libraries. Internet access is required at this stage only.

```bash
# On each machine VM - run as root
chmod +x deps.sh
./deps.sh
```

After `deps.sh` completes successfully on all five machines, **take OpenStack snapshots** of each VM. Label them clearly:
- `snap-m1-itgw-webportal-deps-done`
- `snap-m2-itgw-mailrelay-deps-done`
- etc.

These snapshots are your base images for range spin-up.

### Phase 2 - Challenge Configuration (No Internet Required)

After booting from (or reverting to) the deps-done snapshots, clone this repository onto each respective machine and run `setup.sh`:

```bash
# Clone the repository (use --depth 1 for speed)
git clone https://github.com/<YOUR_ORG>/nexus-itgw-range.git /opt/gridfall

# For M1 - on the 203.x.x.x VM
cd /opt/gridfall/machines/M1-itgw-webportal
chmod +x setup.sh
./setup.sh

# For M2 - on the 203.x.x.x VM
cd /opt/gridfall/machines/M2-itgw-mailrelay
chmod +x setup.sh
./setup.sh

# For M3 - on the 203.x.x.x VM
cd /opt/gridfall/machines/M3-itgw-sso
chmod +x setup.sh
./setup.sh

# For M4 - on the 203.x.x.x VM
cd /opt/gridfall/machines/M4-itgw-netmgmt
chmod +x setup.sh
./setup.sh

# For M5 - on the 203.x.x.x VM
cd /opt/gridfall/machines/M5-itgw-cache
chmod +x setup.sh
./setup.sh
```

### Phase 3 - Honeytrap Deployment (Optional but Recommended)

Deploy the honeytrap decoy listener on each machine after the challenge service is running:

```bash
# On M1 VM
chmod +x /opt/gridfall/Honeytraps/M1-decoy-itgw-webportal.sh
/opt/gridfall/Honeytraps/M1-decoy-itgw-webportal.sh

# Repeat for M2–M5 on their respective VMs
```

### Phase 4 - TTP YAML Deployment (Caldera)

Import all TTP YMLs from the `ttps/` directory into your Caldera instance:

```bash
cp /opt/gridfall/ttps/*.yml /opt/caldera/data/abilities/
# Then restart Caldera or refresh abilities via the UI
```

For each machine, execute the corresponding TTP ability to simulate challenge activation (minimal command - confirms service is running).

### Phase 5 - Take Exercise Snapshots

After all five machines are configured and verified, take final **exercise-ready** snapshots. These are your revert points for each exercise run:
- `snap-m1-itgw-webportal-exercise-ready`
- `snap-m2-itgw-mailrelay-exercise-ready`
- etc.

---

## Verification Checklist

Run these verification checks from a separate attacker VM on the same subnet:

```bash
# M1 - Web portal reachable
curl -s -o /dev/null -w "%{http_code}" http://203.x.x.x:8080/login
# Expected: 200

# M2 - SMTP port open
nc -zv 203.x.x.x 25
# Expected: Connection succeeded

# M3 - SSO portal reachable
curl -s -o /dev/null -w "%{http_code}" http://203.x.x.x:8443/login
# Expected: 200

# M4 - SNMP responding
snmpwalk -v2c -c public 203.x.x.x system 2>/dev/null | head -3
# Expected: SNMPv2-MIB::sysDescr.0 = ...

# M5 - Redis responding
redis-cli -h 203.x.x.x PING
# Expected: PONG
```

---

## Service Management

Each challenge service is managed via systemd. Use standard systemctl commands:

| Machine | Service Name | Check Status |
|---------|-------------|--------------|
| M1 | `pul-portal` | `systemctl status pul-portal` |
| M2 | `postfix` | `systemctl status postfix` |
| M3 | `pul-sso` | `systemctl status pul-sso` |
| M4 | `snmpd` | `systemctl status snmpd` |
| M5 | `redis-server` | `systemctl status redis-server` |

---

## Log Locations

| Machine | Log File | Contents |
|---------|----------|----------|
| M1 | `/var/log/pul-portal/app.log` | Flask app events |
| M1 | `/var/log/pul-portal/reset_requests.log` | Password reset URLs |
| M2 | `/var/log/mail.log` | Postfix relay/connection logs |
| M3 | `/var/log/pul-sso/sso.log` | JWT events (incl. ALG_NONE_ACCEPTED) |
| M4 | `/var/log/syslog` | snmpd access entries |
| M5 | `/var/log/pul-cache/redis.log` | Redis connection log |
| All | `/var/log/pul-honeytrap/M*-decoy-*.log` | Honeytrap hit logs |

---

## Resetting for a New Exercise Run

To reset all machines to their exercise-ready state:
1. Revert each VM to the `exercise-ready` OpenStack snapshot.
2. Boot the VMs.
3. All services auto-start via systemd on boot.
4. No additional configuration is needed.

---

## Troubleshooting

**Flask service won't start (M1/M3):**
```bash
journalctl -u pul-portal -n 30 --no-pager
# Check for missing Python packages - re-run deps.sh if needed
```

**Postfix not accepting connections (M2):**
```bash
journalctl -u postfix -n 20 --no-pager
postconf -n | grep mynetworks   # Should show 0.0.0.0/0
```

**SNMP not responding (M4):**
```bash
systemctl restart snmpd
ss -ulnp | grep 161              # Confirm UDP 161 is listening
```

**Redis not accessible (M5):**
```bash
systemctl restart redis-server
redis-cli PING                   # Should return PONG with no auth prompt
```

---

## Contact

**Exercise Controller:** [White Team Contact]
**Repository:** [GitHub URL]
**Classification:** EXERCISE ONLY - RESTRICTED
