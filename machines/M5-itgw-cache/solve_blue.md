# solve_blue.md — M5 · itgw-cache
## Blue Team Solution Writeup
**Range:** RNG-IT-01 · Corporate Gateway
**Machine:** M5 — Application Cache Host
**Vulnerability:** Redis No-Auth + Sensitive Data in Cache Keys
**MITRE ATT&CK:** T1552 · T1005
**Kill Chain Stage:** Detection → Containment → Eradication → Recovery

---

## Detection

### 1 — Redis Access Log Review
```bash
tail -100 /var/log/pul-cache/redis.log
```

**Anomalous entries — unauthenticated external client:**
```
* Accepted 203.0.1.X:XXXXX
* Client addr=203.0.1.X:XXXXX fd=8 name= age=0 ...
```

Enable Redis command logging for richer visibility:
```bash
redis-cli CONFIG SET loglevel verbose
redis-cli CONFIG SET slowlog-log-slower-than 0
redis-cli SLOWLOG GET 20
```

### 2 — Detect KEYS * Enumeration
```bash
# Redis monitor mode (run briefly for live capture)
redis-cli MONITOR 2>&1 | head -30
# Look for: KEYS *, GET pul:config:*, LRANGE ...
```

Any `KEYS *` command from a non-localhost IP is an enumeration indicator.

### 3 — Audit Sensitive Data in Cache Keys
```bash
redis-cli KEYS "pul:*"
redis-cli GET "pul:config:ldap" | python3 -m json.tool
```

**Critical finding:** LDAP bind credential (`bind_pass`) stored in plaintext in a Redis key.

---

## Containment

### 1 — Enable Authentication Immediately
```bash
# Generate strong password
REDIS_PASS=$(tr -dc 'A-Za-z0-9!@#' < /dev/urandom | head -c 32)
redis-cli CONFIG SET requirepass "${REDIS_PASS}"
echo "Redis password set: ${REDIS_PASS}"

# Persist to config
sed -i "s/# requirepass.*/requirepass ${REDIS_PASS}/" /etc/redis/redis.conf
systemctl restart redis-server
```

### 2 — Bind to Localhost Only
```bash
sed -i 's/^bind 0.0.0.0/bind 127.0.0.1/' /etc/redis/redis.conf
systemctl restart redis-server
```

### 3 — Remove Sensitive Data from Cache
```bash
redis-cli -a "${REDIS_PASS}" DEL "pul:session:admin"
redis-cli -a "${REDIS_PASS}" DEL "pul:config:ldap"
```

### 4 — Block Attacker IP
```bash
ufw deny from <ATTACKER_IP> to any port 6379 comment "M5 Redis recon"
```

### 5 — Rotate Compromised LDAP Credential
`cn=svc-deploy` LDAP bind credential `D3pl0y@PUL2024` is fully compromised. Notify RNG-IT-02 team for immediate rotation.

---

## Eradication

**1. Enforce Redis security baseline:**
```bash
# /etc/redis/redis.conf hardening
sed -i 's/^bind 0.0.0.0/bind 127.0.0.1/' /etc/redis/redis.conf
sed -i 's/^protected-mode no/protected-mode yes/' /etc/redis/redis.conf
# Add requirepass (see above)
# Rename dangerous commands
echo 'rename-command KEYS ""'    >> /etc/redis/redis.conf
echo 'rename-command CONFIG ""'  >> /etc/redis/redis.conf
echo 'rename-command FLUSHALL ""' >> /etc/redis/redis.conf
systemctl restart redis-server
```

**2. Remove credential data from application cache design:**
Credentials (LDAP bind DN + password) must never be stored in Redis. Use:
- Environment variables or `vault read secret/pul/ldap` at startup only.
- Application code reads credentials from a secrets manager at init time — does NOT cache them in Redis.

**3. Application code review:**
Audit all code that writes to Redis — identify and remove any key that stores credentials, tokens, or PII beyond their minimum required TTL.

---

## Recovery
- Rotate `svc-deploy` LDAP credential across all consumers (M5 application, RNG-IT-02 AD forest).
- Implement network firewall rule: Redis port 6379 accessible only from the application server IP, not the full v-Public subnet.
- Deploy Redis AUTH across all cache instances in the estate.
- Add Redis to the security configuration baseline (CIS Redis Benchmark).
- Implement alerting: flag any Redis `KEYS *` or `CONFIG GET` from a non-application IP.

---

## IOCs

| Type | Value |
|---|---|
| Attacker Source IP | `203.0.1.X` |
| Attack Vector | Unauthenticated Redis connection from external IP |
| Attack Commands | `KEYS *`, `GET pul:config:ldap`, `GET pul:session:admin` |
| Compromised Data | LDAP bind DN `cn=svc-deploy` + password `D3pl0y@PUL2024` |
| Pivot Destination | RNG-IT-02 LDAP `203.x.x.x:389` |
| Config File | `/etc/redis/redis.conf` (bind 0.0.0.0, no requirepass) |
