# OPERATION GRIDFALL — Storyline
**Classification:** EXERCISE ONLY — Not for operational use
**Version:** 1.0
**Range:** RNG-IT-01 · Corporate Gateway

---

## Threat Actor: KAAL CHAKRA

KAAL CHAKRA is a fictionalised Advanced Persistent Threat (APT) composite modelled on documented South Asian state-nexus threat actor tradecraft. The actor targets Indian critical information infrastructure (CII) — specifically power utilities, grid operations centres, and associated IT/OT supply chains. KAAL CHAKRA is characterised by patient, multi-stage intrusions with a preference for Living-off-the-Land (LotL) techniques, legitimate tool abuse, and credential-chain exploitation over noisy exploit frameworks.

**Attribution Profile (Exercise):**
- Likely state-sponsored
- Long dwell time (weeks to months before detection)
- Focus: grid operations disruption, SCADA pre-positioning, exfiltration of operational data
- TTPs overlap with APT36 (Transparent Tribe) initial access patterns and TAG-38/RedEcho post-compromise lateral movement

---

## Target Organisation: Prabal Urja Limited (PUL)

Prabal Urja Limited is a fictional Indian power transmission and grid operations company analogous to NTPC and POSOCO combined. PUL operates the NEXUS-IT network — a multi-zone IT infrastructure spanning:

- **v-Public** (`203.0.0.0/8`) — Internet-facing corporate gateway services
- **v-DMZ** (`11.0.0.0/8`) — Development, CI/CD, and integration zone
- **v-Private** (`193.0.0.0/8`) — Internal OT/ICS-adjacent operations networks

PUL's corporate IT is managed from a centralised data centre with regional substations connected via MPLS. The NEXUS-IT platform hosts employee services, internal tooling, CI/CD pipelines, and service integrations bridging IT and OT zones.

---

## Scenario Narrative

### Phase 1 — Initial Access (RNG-IT-01)

KAAL CHAKRA has identified Prabal Urja Limited as a high-value target. Intelligence indicates PUL recently expanded its digital estate with a new Employee Self-Service Portal and an internal Staff Authentication Gateway — both accessible from the v-Public segment.

KAAL CHAKRA operators initiate reconnaissance against the Corporate Gateway (`203.x.x.x/24`). They identify five internet-reachable services and begin a systematic, credential-chaining intrusion:

**M1 — Employee Portal:** An operator identifies a password reset mechanism on the employee self-service portal. By manipulating an HTTP header in the reset request, the operator is able to intercept the admin account's reset token without controlling any external infrastructure. Admin dashboard access reveals an internal mail relay.

**M2 — Mail Relay:** The mail relay is configured as an open relay with no SMTP authentication and exposes user mailboxes through filesystem permission misconfigurations. A pre-planted internal email in the SOC analyst mailbox contains a non-standard header embedding an encoded service account credential for the Staff Authentication Gateway.

**M3 — Authentication Gateway:** Using the harvested service account credential, the operator authenticates to the Staff Authentication Gateway and receives a signed session token. The token's signing mechanism contains a critical flaw — by modifying the algorithm declaration within the token, the operator forges an administrative token without knowledge of the server's signing secret. Administrative access discloses the internal SNMP management host.

**M4 — Network Management Host:** The SNMP service runs with a default community string and exposes custom management extensions containing split credential fragments for the application cache layer. The operator assembles the complete cache access credential and discovers the cache host endpoint.

**M5 — Application Cache:** Connecting to the cache service without authentication, the operator enumerates all stored application data. A configuration key contains the LDAP service account credential for the IT-Ops internal zone — completing the Corporate Gateway intrusion and enabling lateral movement into `RNG-IT-02` (`203.x.x.x/24`).

---

### Phase 2 — Internal Operations (RNG-IT-02) [Subsequent Range]

With the LDAP `svc-deploy` credential, KAAL CHAKRA pivots into the IT-Operations zone — an Active Directory-managed internal network hosting employee workstations, application servers, and internal APIs. This phase focuses on AD enumeration, lateral movement, and privilege escalation within the corporate domain.

*(Scope of this range document — RNG-IT-01 only. RNG-IT-02 documentation is in the NEXUS-IT-OPS range package.)*

---

### Phase 3 — Development Infrastructure (RNG-DEV-01) [Subsequent Range]

From the IT-Ops zone, KAAL CHAKRA targets the CI/CD pipeline and code repositories in the DMZ. The objective shifts toward supply chain compromise — injecting malicious configuration into deployment pipelines that push to OT-adjacent systems.

---

### Phase 4 — Cloud/Kubernetes Fabric (RNG-CLD-01) [Subsequent Range]

The final phase targets the Kubernetes-based cloud fabric (`193.0.0.0/8`), which hosts containerised services that interface with OT systems. Container escape and lateral movement toward SCADA-adjacent APIs represent the ultimate objective of the GRIDFALL operation.

---

## Exercise Objectives

### Red Team Objectives — RNG-IT-01
1. Exploit all five machines in sequence, maintaining the credential chain.
2. Document TTPs, evidence, and pivot artifacts for each machine.
3. Complete RED-REPORT for each machine with operator-validated evidence.

### Blue Team Objectives — RNG-IT-01
1. Detect and investigate attacks on all five machines using available logs.
2. Produce INREP within 30 minutes of detection of each machine.
3. Produce SITREP within 60 minutes of detection of each machine.
4. Propose and (where instructed) apply mitigations.

### Purple Team Objectives
1. Validate detection coverage across all five attack stages.
2. Identify gaps between Red Team TTPs and Blue Team visibility.
3. Produce consolidated lessons-learned and detection improvement plan.

---

## Rules of Engagement

- All activity is confined to the `203.x.x.x/24` subnet for RNG-IT-01.
- No persistence mechanisms beyond the challenge scope.
- No denial-of-service or data destruction.
- Report any unintended vulnerabilities or environment issues to White Team immediately.
- All exercise actions are logged by the range platform.

---

*OPERATION GRIDFALL is a fictional exercise. All organisations, individuals, IP addresses, credentials, and infrastructure described are fabricated for training purposes only.*
