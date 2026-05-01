# solve_blue.md — M3 · itgw-sso
## Blue Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M3 — Staff Authentication Gateway
**Vulnerability:** JWT Algorithm Confusion (alg: none)
**MITRE ATT&CK:** T1606 · T1078
**Kill Chain Stage:** Detection → Containment → Eradication → Recovery

---

## Detection

### 1 — SSO Log Analysis
```bash
grep "ALG_NONE_ACCEPTED" /var/log/pul-sso/sso.log
```

**Malicious log entry pattern:**
```
2024-11-15 10:12:44,331 [WARNING] ALG_NONE_ACCEPTED | sub=svc-deploy-sso role=admin from=203.0.1.X
```
<img width="1617" height="106" alt="image" src="https://github.com/user-attachments/assets/748672b3-18ab-4079-947b-917caf83285c" />


Any `ALG_NONE_ACCEPTED` log entry is a confirmed JWT algorithm confusion attack.

### 2 — Detect Role Escalation via Token Analysis
```bash
# Look for admin access from a service account that should only have analyst role
grep "PORTAL_ACCESS" /var/log/pul-sso/sso.log | grep "role=admin" | grep "svc-deploy"
```
<img width="1747" height="101" alt="image" src="https://github.com/user-attachments/assets/41a58068-897e-427a-81b3-02feb4762e55" />


### 3 — Network-Level Detection
Requests containing a JWT cookie where the header decodes to `{"alg":"none"}` can be detected at WAF/proxy level:
```bash
# On a proxy/WAF, alert on cookie values where the first segment
# base64-decodes to contain '"alg":"none"'
# Signature: pul_staff_token header segment = eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0
```

---

## Containment

### 1 — Reject alg:none Tokens Immediately
Apply the patch (see Eradication). Restart service to invalidate all active sessions.

### 2 — Block Attacker Source IP
```bash
ufw deny from <ATTACKER_IP> to any port 8443 comment "M3 JWT attack"
```

### 3 — Rotate JWT Secret
Even though `alg:none` bypasses the secret, rotate it to invalidate any legitimately signed tokens the attacker may have captured:
- Edit `/opt/pul-sso/app/app.py` — change `JWT_SECRET` value.
- Restart the service: `systemctl restart pul-sso`

---

## Eradication — Patch the Vulnerability

**Vulnerable code in `/opt/pul-sso/app/app.py` — `decode_jwt_vulnerable()`:**
```python
# VULNERABLE — accepts alg: none
if alg == 'none':
    payload = json.loads(base64.urlsafe_b64decode(payload_padded))
    return payload
```

**Patched code — whitelist only HS256, reject all others:**
```python
# PATCHED — strict algorithm whitelist
ALLOWED_ALGORITHMS = ['HS256']

def decode_jwt_secure(token: str):
    try:
        # PyJWT's decode() rejects alg:none by default when algorithms= is specified
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=ALLOWED_ALGORITHMS,   # explicit whitelist — blocks none
            options={"verify_exp": True}
        )
        return payload
    except jwt.InvalidTokenError as exc:
        logging.warning(f"JWT_INVALID | {exc} | from={request.remote_addr}")
        return None
```

Apply patch and restart:
```bash
systemctl restart pul-sso
```

**Verification:**
```bash
# Forge a none-alg token and confirm rejection
HEADER=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(echo -n '{"sub":"test","role":"admin","iat":1,"exp":9999999999}' | base64 | tr '+/' '-_' | tr -d '=')
curl -s -b "pul_staff_token=${HEADER}.${PAYLOAD}." http://203.x.x.x:8443/staff-portal
# Should redirect to /login — not render portal
```

---

## Recovery
- Rotate `svc-deploy-sso` service account credential (chain: exposed at M2, used at M3).
- Enforce PyJWT `algorithms=` whitelist in all JWT decode calls across the application estate.
- Add WAF rule: reject any request with a JWT cookie whose header `alg` is `"none"`.
- Implement token binding or short-lived tokens (≤15 min) for privileged service accounts.
- Conduct code audit of all JWT implementation points across PUL digital estate.

---

## IOCs

| Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Forged Token Indicator | JWT header decodes to `{"alg":"none"}` |
| Log Signature | `ALG_NONE_ACCEPTED` in `/var/log/pul-sso/sso.log` |
| Compromised Account | `svc-deploy-sso` (role escalated to admin) |
| Data Exfiltrated | SNMP host `203.x.x.x:161` from admin panel |
