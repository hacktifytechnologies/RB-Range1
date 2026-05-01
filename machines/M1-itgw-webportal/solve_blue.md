# solve_blue.md — M1 · itgw-webportal
## Blue Team Solution Writeup

**Range:** RNG-IT-01 · Corporate Gateway  
**Machine:** M1 — Prabal Urja Limited Employee Self-Service Portal  
**Vulnerability:** HTTP Host Header Injection gated by `Host: 127.0.0.1`  
**MITRE ATT&CK:** T1190 · T1078.003 · T1565.001  
**Severity:** High  
**Kill Chain Stage:** Detection → Containment → Eradication → Recovery

---

## Objective

Detect attempts to abuse the password reset workflow using the localhost Host header, identify any compromised account, invalidate tokens, contain active sessions, and patch the application so reset URLs are generated from a trusted configured host only.

In this challenge version, arbitrary domains such as `attacker.com` should not generate usable reset tokens. The malicious condition is specifically:

```http
Host: 127.0.0.1
```

---

## Detection

### 1 — Application Reset Log Analysis

The primary detection surface is:

```bash
/var/log/pul-portal/reset_requests.log
```

View recent reset activity:

```bash
cat /var/log/pul-portal/reset_requests.log
```

Suspicious pattern:

```text
RESET REQUEST
  Recipient : admin@prabalurja.in
  Reset URL : http://127.0.0.1/reset-password?token=<TOKEN>
  Source IP : 203.0.1.X
```

Any password reset URL containing `http://127.0.0.1/` is suspicious because external users should not be able to cause the application to generate localhost reset links.

Detection query:

```bash
grep -E "Reset URL" /var/log/pul-portal/reset_requests.log | grep "127.0.0.1"
```

Also confirm that arbitrary attacker domains are not working:

```bash
grep -E "Reset URL" /var/log/pul-portal/reset_requests.log | grep -E "attacker.com|evil.com|ngrok|burpcollaborator"
```

Expected result after the fixed challenge setup: no usable reset links should be generated for those arbitrary domains.

---

### 2 — Application Login Log Correlation

Cross-reference successful admin logins after suspicious reset activity:

```bash
grep "Successful login" /var/log/pul-portal/app.log | grep "admin@prabalurja.in"
```

Suspicious pattern:

```text
Successful login: admin@prabalurja.in from 203.0.1.X
```

Correlate the source IP with the earlier reset request source IP.

---

### 3 — Network Level Detection

Look for password reset requests where the request was sent to the public target IP but the Host header was overridden to localhost.

HTTP signature:

```http
POST /forgot-password HTTP/1.1
Host: 127.0.0.1
Content-Type: application/x-www-form-urlencoded

email=admin%40prabalurja.in
```

Also monitor reset completion:

```http
POST /reset-password HTTP/1.1
Host: 127.0.0.1
Content-Type: application/x-www-form-urlencoded

token=<TOKEN>&new_password=<PASSWORD>
```

Suricata/Snort rule concept:

```text
alert http any any -> 203.x.x.x 8080 (
  msg:"PUL M1 Host Header Injection - Localhost Password Reset";
  flow:established,to_server;
  http.method:"POST";
  http.uri:"/forgot-password";
  http.header;
  content:"Host|3a| 127.0.0.1";
  sid:9000101;
  rev:2;
)
```

---

## Containment

### 1 — Invalidate All Active Reset Tokens

```bash
sqlite3 /opt/pul-portal/data/users.db \
  "DELETE FROM reset_tokens;"
echo "[+] All reset tokens invalidated."
```

### 2 — Rotate the Admin Password

```bash
NEW_HASH=$(python3 -c "import hashlib; print(hashlib.sha256('TempAdmin@PUL!Secure2024'.encode()).hexdigest())")

sqlite3 /opt/pul-portal/data/users.db \
  "UPDATE users SET password='${NEW_HASH}' WHERE email='admin@prabalurja.in';"

echo "[+] Admin password rotated."
```

### 3 — Block the Attacker Source IP

```bash
ufw deny from <ATTACKER_IP> to any port 8080 comment "M1 localhost Host header reset abuse"
```

### 4 — Restart the Portal Service

```bash
systemctl restart pul-portal
```

---

## Eradication — Patch the Vulnerability

The root cause is that the password reset logic uses the request `Host` header when constructing or accepting sensitive reset flows.

### Secure Fix

Use a configured trusted public host for reset URLs and do not allow sensitive password reset flows to depend on client-supplied Host headers.

Example secure code:

```python
TRUSTED_PUBLIC_HOST = "203.x.x.x:8080"

reset_url = f"http://{TRUSTED_PUBLIC_HOST}/reset-password?token={token}"
```

Recommended Flask hardening:

```python
app.config["SERVER_NAME"] = "203.x.x.x:8080"
```

For production, place the app behind a reverse proxy and enforce an allowlist for Host headers at the proxy layer.

---

## Verification

### Confirm `attacker.com` Does Not Work

```bash
curl -i -s -X POST http://203.x.x.x:8080/forgot-password \
  -H "Host: attacker.com" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=admin@prabalurja.in"
```

Expected:

```text
HTTP/1.1 403 FORBIDDEN
```

### Confirm Challenge Trigger Still Works

```bash
curl -i -s -X POST http://203.x.x.x:8080/forgot-password \
  -H "Host: 127.0.0.1" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=admin@prabalurja.in"
```

Expected response contains:

```text
Reset link: http://127.0.0.1/reset-password?token=<TOKEN>
```

### Confirm Reset Also Requires `Host: 127.0.0.1`

```bash
curl -i -s -X POST http://203.x.x.x:8080/reset-password \
  -H "Host: attacker.com" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=<TOKEN>&new_password=Test@12345"
```

Expected:

```text
HTTP/1.1 403 FORBIDDEN
```

---

## Recovery

1. Rotate passwords for accounts that received reset tokens during the incident window.
2. Invalidate all reset tokens.
3. Review `/var/log/pul-portal/reset_requests.log` and `/var/log/pul-portal/app.log`.
4. Implement MFA for admin accounts.
5. Rate-limit `/forgot-password`.
6. Add reverse proxy Host header validation.
7. Stop reflecting reset links in the HTTP response body in production.

---

## Timeline Reconstruction

| Time | Event |
|---|---|
| T+00:00 | Attacker sends POST `/forgot-password` with `Host: 127.0.0.1` |
| T+00:01 | App generates localhost reset URL and token |
| T+00:02 | Attacker extracts token from response body/source |
| T+00:03 | Attacker posts to `/reset-password` with `Host: 127.0.0.1` |
| T+00:04 | Admin password is changed |
| T+00:05 | Attacker logs in as admin and extracts mail relay details |

---

## IOCs

| Type | Value |
|---|---|
| Target Account | `admin@prabalurja.in` |
| Attack Path | `POST /forgot-password` with `Host: 127.0.0.1` |
| Reset Completion Path | `POST /reset-password` with `Host: 127.0.0.1` |
| Log File | `/var/log/pul-portal/reset_requests.log` |
| Anomaly | Reset URL contains `http://127.0.0.1/reset-password?token=` |

---

## Recommendations

- Never trust client-supplied `Host` headers for password reset links.
- Never reflect password reset tokens in HTTP responses in production.
- Enforce Host header allowlisting at the reverse proxy.
- Add MFA for privileged users.
- Log and alert on reset URLs containing loopback values such as `127.0.0.1`, `localhost`, `[::1]`, or encoded loopback equivalents.
