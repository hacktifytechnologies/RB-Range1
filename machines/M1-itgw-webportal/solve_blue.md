# solve_blue.md — M1 · itgw-webportal
## Blue Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway  
**Machine:** M1 — Prabal Urja Limited Employee Self-Service Portal  
**Vulnerability:** HTTP Host Header Injection in Password Reset  
**MITRE ATT&CK:** T1078 · T1190  
**Severity:** High  
**Kill Chain Stage:** Detection → Containment → Eradication → Recovery

---

## Objective
Detect the Host Header Injection attack against the PUL Employee Portal, identify the compromised account, contain the session, eradicate the misconfiguration, and produce incident documentation.

---

## Detection

### 1 — Application Log Analysis

The primary detection surface is the reset request log at `/var/log/pul-portal/reset_requests.log`.

```bash
cat /var/log/pul-portal/reset_requests.log
```

**Malicious entry pattern — Host header poisoning:**
```
[2024-11-15T09:43:12.334211] RESET REQUEST
  Recipient : admin@prabalurja.in
  Reset URL : http://attacker.com/reset-password?token=<TOKEN>
  Source IP : 203.0.1.X
------------------------------------------------------------
```

<img width="1936" height="411" alt="image" src="https://github.com/user-attachments/assets/62fce851-d4e6-426e-93eb-cb056b4dd07c" />


**Indicator:** The `Reset URL` domain does NOT match the server's actual hostname (`203.x.x.x:8080`). Any entry where the reset URL contains a domain other than the server's own IP/hostname is a confirmed Host Header Injection attempt.

```bash
# Detection query — find anomalous reset URLs
grep -E "Reset URL" /var/log/pul-portal/reset_requests.log | \
  grep -v "203.x.x.x"
```

### 2 — App Log — Successful Post-Reset Login

Cross-reference `app.log` for successful logins after the anomalous reset:
```bash
grep "Successful login" /var/log/pul-portal/app.log | \
  grep "admin@prabalurja.in"
```

Expected suspicious output:
```
2024-11-15 09:45:03,221 [INFO] Successful login: admin@prabalurja.in from 203.0.1.X
```

### 3 — Network Level Detection

Look for HTTP requests with a `Host` header that does not match the server address in the reverse proxy or network IDS logs. Signature:

```
POST /forgot-password HTTP/1.1
Host: <anything-not-203.x.x.x>
Content-Type: application/x-www-form-urlencoded
email=admin%40prabalurja.in
```

Snort/Suricata rule concept:
```
alert http any any -> 203.x.x.x 8080 (
  msg:"Host Header Injection - Password Reset Poisoning";
  flow:established,to_server;
  http.method:"POST";
  http.uri:"/forgot-password";
  http.header;
  content:!"Host: 203.x.x.x";
  sid:9000101; rev:1;
)
```

---

## Containment

### Immediate Actions

**1. Invalidate all active reset tokens:**
```bash
sqlite3 /opt/pul-portal/data/users.db \
  "DELETE FROM reset_tokens;"
echo "[+] All reset tokens invalidated."
```

**2. Force password re-set for the admin account to a known-good value:**
```bash
NEW_HASH=$(python3 -c "import hashlib; print(hashlib.sha256('TempAdmin@PUL!Secure2024'.encode()).hexdigest())")
sqlite3 /opt/pul-portal/data/users.db \
  "UPDATE users SET password='${NEW_HASH}' WHERE email='admin@prabalurja.in';"
echo "[+] Admin password rotated."
```

**3. Block the attacker's source IP at the host firewall:**
```bash
ufw deny from <ATTACKER_IP> to any port 8080 comment "M1 - Host Header Attack"
```

**4. Kill any active Flask sessions** by restarting the service (clears in-memory session store):
```bash
systemctl restart pul-portal
```

---

## Eradication — Patch the Vulnerability

The root cause is in `/opt/pul-portal/app/app.py` — the `forgot_password()` function trusts the `Host` header unconditionally.

**Vulnerable code (lines ~55–56):**
```python
# VULNERABLE
host = request.headers.get('Host', request.host)
reset_url = f"http://{host}/reset-password?token={token}"
```

**Patched code — whitelist the allowed host:**
```python
# PATCHED
ALLOWED_HOST = "203.x.x.x:8080"   # Set to actual server hostname/IP
reset_url = f"http://{ALLOWED_HOST}/reset-password?token={token}"
```

Apply the patch:
```bash
sed -i \
  "s|host = request.headers.get('Host', request.host)|host = '203.x.x.x:8080'  # PATCHED: Hardcoded allowed host|" \
  /opt/pul-portal/app/app.py

sed -i \
  's|reset_url = f"http://{host}/reset-password|reset_url = f"http://203.x.x.x:8080/reset-password|' \
  /opt/pul-portal/app/app.py

systemctl restart pul-portal
```

**Verification — confirm patch works:**
```bash
curl -s -X POST http://203.x.x.x:8080/forgot-password \
  -H "Host: attacker.com" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=admin@prabalurja.in" | grep "Reset link"
# Should now show: http://203.x.x.x:8080/reset-password?token=...
# NOT http://attacker.com/...
```

---

## Recovery

1. Rotate all employee passwords for accounts that received reset tokens during the attack window.
2. Enable rate-limiting on `/forgot-password` (max 3 requests per IP per 10 minutes).
3. Add `X-Frame-Options`, `Content-Security-Policy`, and `Strict-Transport-Security` headers.
4. Consider migrating to HTTPS to prevent token interception in transit.
5. Implement alerting: auto-notify CERT-In SOC whenever a reset URL domain != configured server hostname.

---

## Timeline Reconstruction

| Time | Event |
|---|---|
| T+00:00 | Attacker sends POST /forgot-password with `Host: attacker.com` |
| T+00:01 | App constructs and reflects reset URL with attacker-controlled domain |
| T+00:02 | Attacker extracts token from HTTP response |
| T+00:03 | Attacker uses token to reset admin password via /reset-password |
| T+00:04 | Attacker logs in as admin — admin dashboard accessed |
| T+00:05 | Attacker exfiltrates mail relay info (203.x.x.x:25) from dashboard |

---

## IOCs

| Type | Value |
|---|---|
| Source IP | `203.0.1.X` (attacker) |
| Target Account | `admin@prabalurja.in` |
| Attack Path | `POST /forgot-password` with manipulated `Host` header |
| Log File | `/var/log/pul-portal/reset_requests.log` |
| Anomaly | Reset URL domain ≠ `203.x.x.x` |

---

## Recommendations

- Never trust the `Host` header for constructing sensitive URLs — always use a hardcoded, configured `SERVER_NAME`.
- Implement `SERVER_NAME` in Flask config: `app.config['SERVER_NAME'] = '203.x.x.x:8080'`.
- Add CERT-In incident report for credential compromise of admin account.
- Implement MFA for all admin-role accounts.
