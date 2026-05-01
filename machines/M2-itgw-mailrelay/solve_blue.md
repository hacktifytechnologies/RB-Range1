# solve_blue.md — M2 · itgw-mailrelay
## Blue Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M2 — SMTP Open Relay + Exposed Mail Spool
**Vulnerability:** Postfix Open Relay + World-Readable Mail Spool + Credential in Email Header
**MITRE ATT&CK:** T1114.001 · T1071.003
**Kill Chain Stage:** Detection → Containment → Eradication → Recovery

---

## Detection

### 1 — Postfix Mail Log Analysis
```bash
tail -n 100 /var/log/mail.log | grep -E "relay|VRFY|from="
```

**Indicators of open relay abuse:**
```
postfix/smtpd: client=unknown[203.0.1.X] ... EHLO attacker.com
postfix/smtpd: NOQUEUE: reject... OR: status=sent (250 Ok: queued)
```

**VRFY enumeration:**
```bash
grep "VRFY" /var/log/mail.log
```
Any external IP issuing VRFY commands is enumeration activity.

**Unauthenticated relay — detect accepted outbound mail from external IP:**
```bash
grep "from=<" /var/log/mail.log | grep -v "203.x.x.x"
```

### 2 — Mail Spool Permission Audit
```bash
ls -la /var/mail/
# Malicious: -rw-r--r-- 1 socanalyst mail ... socanalyst  (644 — world-readable)
# Correct:   -rw-rw---- 1 socanalyst mail ... socanalyst  (660)
```

### 3 — Detect Credential in Email Header
```bash
grep "X-Internal-Auth-Token" /var/mail/socanalyst
# Any credential embedded in email headers is a critical finding
```

---

## Containment

**1. Disable open relay immediately:**
```bash
postconf -e "mynetworks = 127.0.0.0/8 203.x.x.x/32"
postconf -e "smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"
systemctl reload postfix
```

**2. Disable VRFY:**
```bash
postconf -e "disable_vrfy_command = yes"
systemctl reload postfix
```

**3. Fix mail spool permissions:**
```bash
chmod 660 /var/mail/socanalyst
chown socanalyst:mail /var/mail/socanalyst
# Verify all spools
chmod 660 /var/mail/*
```

**4. Rotate the compromised SSO credential immediately:**
The `X-Internal-Auth-Token` value `svc-deploy-sso:SSO@Prabal!2024` must be treated as compromised. Notify M3 team to rotate this service account credential.

**5. Block attacker source IP at firewall:**
```bash
ufw deny from <ATTACKER_IP> to any port 25 comment "M2 relay abuse"
```

---

## Eradication

**1. Remove embedded credential from mail spool:**
```bash
# Remove the offending seeded email (contains the exposed credential)
> /var/mail/socanalyst
chown socanalyst:mail /var/mail/socanalyst
chmod 660 /var/mail/socanalyst
```

**2. Enforce authenticated SMTP:**
```bash
# Install SASL for authenticated relay
apt-get install -y libsasl2-modules sasl2-bin
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_sasl_security_options = noanonymous"
postconf -e "broken_sasl_auth_clients = yes"
systemctl restart postfix
```

**3. Implement policy — never embed credentials in email headers:**
Update PUL-IT-POL-0044 to prohibit automated credential distribution via email. Use a secrets management system (e.g., HashiCorp Vault — as deployed in the cloud zone) instead.

---

## Recovery
- Rotate `svc-deploy-sso` credential in all systems where it is used (M3 SSO gateway).
- Add mail relay to internal monitoring — alert on unauthenticated SMTP relay attempts.
- Implement SPF/DKIM/DMARC for `prabalurja.in` to prevent spoofing.
- Conduct mail security review: audit all automated emails for embedded secrets.

---

## IOCs

| Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Attack Vector | Unauthenticated SMTP relay + VRFY enumeration |
| Compromised Credential | `svc-deploy-sso:SSO@Prabal!2024` (base64 decoded) |
| Artifact Location | `/var/mail/socanalyst` — `X-Internal-Auth-Token` header |
| Postfix Config Issue | `mynetworks = 0.0.0.0/0` + `disable_vrfy_command = no` |
