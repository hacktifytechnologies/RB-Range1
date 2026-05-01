# Assessment Questions — RNG-IT-01 · Corporate Gateway
## OPERATION GRIDFALL | Prabal Urja Limited — NEXUS-IT Purple Team Exercise
**Instructions:** Answer all questions based on your analysis and exploitation of each machine.
MCQ = Multiple Choice (select one). FIB = Fill in the Blank (single precise answer).

---

## M1 — itgw-webportal (203.x.x.x:8080)
*Challenge: HTTP Host Header Injection in Password Reset*

**Q1.1 [MCQ]** Which HTTP request header did the attacker manipulate to redirect the password reset token to an attacker-controlled domain?

- A) `X-Forwarded-For`
- B) `Host`
- C) `Referer`
- D) `Authorization`

**Answer:** B

---

**Q1.2 [MCQ]** After successfully exploiting the password reset mechanism, what role was assigned to the admin account's session?

- A) `superuser`
- B) `operator`
- C) `admin`
- D) `root`

**Answer:** C

---

**Q1.3 [MCQ]** Which Flask object did the vulnerable code incorrectly use to construct the password reset URL?

- A) `request.remote_addr`
- B) `request.method`
- C) `request.cookies`
- D) `request.headers.get('Host')`

**Answer:** D

---

**Q1.4 [FIB]** What is the exact name of the HTTP header that must be hardcoded or validated server-side to prevent Host Header Injection in password reset flows?

**Answer:** `Host`

---

**Q1.5 [FIB]** What was the internal mail relay IP address disclosed on the admin dashboard after successfully authenticating as the admin account?

**Answer:** `203.x.x.x`

---

## M2 — itgw-mailrelay (203.x.x.x:25)
*Challenge: SMTP Open Relay + World-Readable Mail Spool*

**Q2.1 [MCQ]** Which Postfix configuration directive set to `0.0.0.0/0` enabled unauthenticated mail relay from any source IP?

- A) `relay_domains`
- B) `mydestination`
- C) `mynetworks`
- D) `inet_interfaces`

**Answer:** C

---

**Q2.2 [MCQ]** Which SMTP protocol command can be used to verify whether a specific username exists as a valid local account on the mail server?

- A) `HELO`
- B) `EXPN`
- C) `RCPT TO`
- D) `VRFY`

**Answer:** D

---

**Q2.3 [MCQ]** What Linux file permission mode (numeric) was set on `/var/mail/socanalyst` that made it accessible to any local user?

- A) `600`
- B) `660`
- C) `644`
- D) `755`

**Answer:** C

---

**Q2.4 [FIB]** What was the exact name of the non-standard email header in the seeded mail that contained the encoded authentication token?

**Answer:** `X-Internal-Auth-Token`

---

**Q2.5 [FIB]** After base64-decoding the value of the `X-Internal-Auth-Token` header, what was the username portion of the extracted credential?

**Answer:** `svc-deploy-sso`

---

## M3 — itgw-sso (203.x.x.x:8443)
*Challenge: JWT Algorithm Confusion (alg: none)*

**Q3.1 [MCQ]** Which JWT algorithm value, when placed in the token header, caused the PUL Staff Authentication Gateway to skip signature verification entirely?

- A) `RS256`
- B) `HS512`
- C) `none`
- D) `ES256`

**Answer:** C

---

**Q3.2 [MCQ]** A JWT token consists of three sections separated by dots. In what order do they appear?

- A) Payload · Header · Signature
- B) Header · Signature · Payload
- C) Header · Payload · Signature
- D) Signature · Header · Payload

**Answer:** C

---

**Q3.3 [MCQ]** Which log file contained the warning entry `ALG_NONE_ACCEPTED` that confirmed a JWT algorithm confusion attack had occurred on M3?

- A) `/var/log/auth.log`
- B) `/var/log/pul-sso/sso.log`
- C) `/var/log/syslog`
- D) `/var/log/pul-portal/app.log`

**Answer:** B

---

**Q3.4 [FIB]** What is the name of the JSON field within the JWT header section that specifies the signing algorithm?

**Answer:** `alg`

---

**Q3.5 [FIB]** After forging an admin-role JWT using algorithm confusion, what was the SNMP management host IP address revealed on the admin infrastructure panel?

**Answer:** `203.x.x.x`

---

## M4 — itgw-netmgmt (203.x.x.x:161/UDP)
*Challenge: SNMP v2c Default Community String + Credential OIDs*

**Q4.1 [MCQ]** Which SNMP version uses cleartext community strings for authentication and was exploited in this challenge?

- A) SNMPv1 only
- B) SNMPv3 only
- C) SNMPv2c
- D) SNMPv2u

**Answer:** C

---

**Q4.2 [MCQ]** Which command-line tool was used to enumerate the full SNMP MIB tree and discover the private enterprise OIDs on M4?

- A) `nmap`
- B) `snmpget`
- C) `snmpwalk`
- D) `snmpset`

**Answer:** C

---

**Q4.3 [MCQ]** The snmpd configuration used `extend` directives to expose credential fragments as OID values. Under which root OID prefix were the private enterprise extensions found?

- A) `.1.3.6.1.2.1`
- B) `.1.3.6.1.4.1.8072.1.3.2`
- C) `.1.3.6.1.6.3`
- D) `.1.3.6.1.2.1.25`

**Answer:** B

---

**Q4.4 [FIB]** What was the SNMP read-only community string configured on the PUL network management host?

**Answer:** `public`

---

**Q4.5 [FIB]** The Redis service account credential was split across two OID extension values (`pul-cred-part1` and `pul-cred-part2`). What is the complete assembled password formed by concatenating both parts?

**Answer:** `r3d1s-cache@PUL!2024`

---

## M5 — itgw-cache (203.x.x.x:6379)
*Challenge: Redis No-Authentication Exposure + Credentials in Cache Keys*

**Q5.1 [MCQ]** Which Redis command was used to enumerate all stored keys in the cache and discover the sensitive key namespace?

- A) `SCAN 0`
- B) `LIST *`
- C) `SHOW KEYS`
- D) `KEYS *`

**Answer:** D

---

**Q5.2 [MCQ]** Which Redis configuration directive — intentionally absent in M5 — would have enforced password-based authentication for all incoming connections?

- A) `bind-password`
- B) `requirepass`
- C) `auth-required yes`
- D) `acl-password`

**Answer:** B

---

**Q5.3 [MCQ]** What Redis configuration value for the `bind` directive restricted the service to only accept connections from the local machine?

- A) `bind 0.0.0.0`
- B) `bind *`
- C) `bind 127.0.0.1`
- D) `bind localhost`

**Answer:** C

---

**Q5.4 [FIB]** What was the exact Redis key name that contained the LDAP service account configuration including the pivot credential for RNG-IT-02?

**Answer:** `pul:config:ldap`

---

**Q5.5 [FIB]** What was the password of the LDAP `svc-deploy` service account extracted from the Redis cache key, enabling pivot into RNG-IT-02?

**Answer:** `D3pl0y@PUL2024`

---

*Assessment questions prepared by: White Team / Exercise Controller*
*Classification: EXERCISE RESTRICTED — Do not distribute outside the exercise environment*
