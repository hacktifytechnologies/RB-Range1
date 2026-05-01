#!/usr/bin/env bash
# =============================================================================
# RNG-IT-01 | M3 — itgw-sso | Honeytraps (7 decoys)
# Ports:
#   8636  — LDAPS banner (socket)
#   8300  — SAML Identity Provider Console (web)
#   8301  — OAuth 2.0 Authorization Server (web)
#   8302  — MFA / TOTP Admin Portal (web)
#   8303  — Identity Governance & Provisioning (web)
#   8304  — CyberArk PAM-style Privileged Access (web)
#   8305  — SSO Federation Metadata Viewer (web)
# =============================================================================
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "[!] Must be run as root." >&2; exit 1; fi
TRAP_DIR="/opt/pul-honeytrap/itgw-m3"; LOG_DIR="/var/log/pul-honeytrap"
mkdir -p "${TRAP_DIR}" "${LOG_DIR}"

make_svc() {
  local name=$1 script=$2 port=$3
  cat > /etc/systemd/system/pul-decoy-${name}.service << EOF
[Unit]
Description=PUL Honeytrap — ${name} (port ${port})
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 ${script}
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "pul-decoy-${name}" --quiet
  systemctl restart "pul-decoy-${name}"
}

# ─── D1: LDAPS Banner — port 8636 ─────────────────────────────────────────────
cat > "${TRAP_DIR}/ldaps-banner.py" << 'PYEOF'
#!/usr/bin/env python3
import socket,threading,logging
LOG="/var/log/pul-honeytrap/itgw-m3-ldaps.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
# Simulate a TLS-wrapped LDAP — just send a raw TLS-like hello then close
BANNER=b"\x00\x00\x00\x00"  # partial LDAP framing — triggers banner-grab detection
def handle(conn,addr):
    logging.warning(f"LDAPS_CONNECT|src={addr[0]}")
    try:
        # TLS ClientHello will come in — log it and drop
        data=conn.recv(256)
        if data: logging.warning(f"LDAPS_TLS|src={addr[0]}|len={len(data)}|first_bytes={data[:8].hex()}")
        conn.sendall(b"\x15\x03\x03\x00\x02\x02\x28")  # TLS Alert: handshake_failure
    except: pass
    finally: conn.close()
srv=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
srv.bind(("0.0.0.0",8636));srv.listen(10)
while True:
    c,a=srv.accept()
    threading.Thread(target=handle,args=(c,a),daemon=True).start()
PYEOF
make_svc "itgw-m3-ldaps" "${TRAP_DIR}/ldaps-banner.py" 8636

# ─── D2: SAML Identity Provider Console — port 8300 ──────────────────────────
mkdir -p "${TRAP_DIR}/saml"
cat > "${TRAP_DIR}/saml/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL SAML IdP Console</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#f0f7ff;color:#1e3a5f;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#1e3a5f;border-bottom:3px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#c4a53e;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.4);font-size:11px}
.main{flex:1;padding:20px;max-width:900px;margin:0 auto;width:100%}
.panel{background:#fff;border:1px solid #bfdbfe;border-radius:8px;overflow:hidden;margin-bottom:14px;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.ph{background:#1e3a5f;border-bottom:2px solid #c4a53e;padding:10px 14px;color:#c4a53e;font-size:12.5px;font-weight:700}
.pb{padding:14px}
.row{display:flex;padding:8px 0;border-bottom:1px solid #eff6ff;font-size:12.5px;gap:12px}
.row:last-child{border-bottom:none}
.rk{width:200px;flex-shrink:0;color:#6b7280;font-size:12px}.rv{flex:1;color:#1e3a5f;font-family:monospace;font-size:11.5px;word-break:break-all}
.rv.ok{color:#059669}.rv.warn{color:#d97706}.rv.err{color:#dc2626}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700;margin-left:6px}
.b-ok{background:rgba(5,150,105,.12);color:#047857}.b-warn{background:rgba(217,119,6,.12);color:#b45309}
.sp-table{width:100%;border-collapse:collapse;font-size:12.5px}
.sp-table th{text-align:left;padding:7px 10px;background:#eff6ff;color:#6b7280;font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;border-bottom:1px solid #bfdbfe}
.sp-table td{padding:8px 10px;border-bottom:1px solid #eff6ff;color:#1e3a5f}
.sp-table tr:hover td{background:#f0f7ff}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:360px;overflow:hidden}
.lh{background:#1e3a5f;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#c4a53e;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#6b7280;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input{width:100%;padding:8px 10px;border:1px solid #bfdbfe;border-radius:4px;font-size:13px}
.btn{width:100%;padding:9px;background:#1e3a5f;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">🔐 SAML IdP Admin Console — Login</div>
<div class="lbody">
<div class="fg"><label>Admin Username</label><input type="text" placeholder="sso-admin or admin"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>🔐 PUL SAML Identity Provider Console</h1><p>SimpleSAMLphp 2.1 | sso.prabalurja.in</p></div>
<div class="main">
<div class="panel"><div class="ph">IdP Configuration</div><div class="pb">
<div class="row"><span class="rk">Entity ID</span><span class="rv ok">https://sso.prabalurja.in/saml/idp</span></div>
<div class="row"><span class="rk">SSO Endpoint (POST)</span><span class="rv ok">https://sso.prabalurja.in/saml/sso/post</span></div>
<div class="row"><span class="rk">SLO Endpoint (Redirect)</span><span class="rv ok">https://sso.prabalurja.in/saml/slo/redirect</span></div>
<div class="row"><span class="rk">Signing Certificate</span><span class="rv warn">pul-saml-signing-2024.crt <span class="badge b-warn">EXPIRES 2025-02-10</span></span></div>
<div class="row"><span class="rk">Attribute Source</span><span class="rv ok">LDAP — ldap://203.x.x.x:389 (ou=users,dc=prabalurja,dc=in)</span></div>
</div></div>
<div class="panel"><div class="ph">Registered Service Providers (5)</div><div class="pb">
<table class="sp-table">
<tr><th>SP Entity ID</th><th>Name</th><th>Assertion Consumer</th><th>Status</th></tr>
<tr><td style="font-family:monospace;font-size:11px">urn:pul:git:gitea</td><td>Gitea DevOps Portal</td><td>http://203.x.x.x:3000/user/saml/acs</td><td><span class="badge b-ok">ACTIVE</span></td></tr>
<tr><td style="font-family:monospace;font-size:11px">urn:pul:monitor</td><td>Monitoring Portal</td><td>http://203.x.x.x:9090/saml/acs</td><td><span class="badge b-ok">ACTIVE</span></td></tr>
<tr><td style="font-family:monospace;font-size:11px">urn:pul:helpdesk</td><td>IT Helpdesk</td><td>http://203.x.x.x:8181/saml/acs</td><td><span class="badge b-ok">ACTIVE</span></td></tr>
<tr><td style="font-family:monospace;font-size:11px">urn:pul:dms</td><td>Document Management</td><td>http://203.x.x.x:8282/saml/acs</td><td><span class="badge b-warn">CERT_MISMATCH</span></td></tr>
<tr><td style="font-family:monospace;font-size:11px">urn:pul:awx</td><td>Ansible AWX</td><td>http://203.x.x.x:8080/saml/acs</td><td><span class="badge b-ok">ACTIVE</span></td></tr>
</table></div></div></div>
</body></html>
HTML
cat > "${TRAP_DIR}/saml/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m3-saml.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,f,*a): logging.warning(f"HIT|src={self.client_address[0]}|path={self.path}")
    def do_GET(self):
        self.send_response(200);self.send_header("Content-Type","text/html");self.end_headers()
        with open(os.path.join(os.path.dirname(__file__),"index.html"),"rb") as f: self.wfile.write(f.read())
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0));b=self.rfile.read(n)
        logging.warning(f"POST|src={self.client_address[0]}|body={repr(b[:200])}")
        self.send_response(302);self.send_header("Location","/");self.end_headers()
http.server.HTTPServer(("0.0.0.0",8300),H).serve_forever()
PYEOF
make_svc "itgw-m3-saml" "${TRAP_DIR}/saml/server.py" 8300

# ─── D3: OAuth 2.0 Authorization Server — port 8301 ──────────────────────────
mkdir -p "${TRAP_DIR}/oauth"
cat > "${TRAP_DIR}/oauth/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL OAuth Authorization Server</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#0a0e1a;min-height:100vh;display:flex;align-items:center;justify-content:center;color:#c9d1d9}
.card{background:#161b22;border:1px solid #30363d;border-radius:12px;width:420px;overflow:hidden;box-shadow:0 20px 50px rgba(0,0,0,.5)}
.ch{background:linear-gradient(135deg,#1e1b4b,#312e81);border-bottom:2px solid #c4a53e;padding:24px;text-align:center}
.ch .scope-icon{font-size:42px;margin-bottom:8px}
.ch h2{color:#fff;font-size:16px;font-weight:700;margin-bottom:4px}
.ch .app-name{color:#c4a53e;font-size:13px;font-weight:600}
.ch p{color:rgba(255,255,255,.4);font-size:11px;margin-top:6px}
.cb{padding:22px}
.scope-section{margin-bottom:18px}
.scope-section h3{font-size:11px;text-transform:uppercase;letter-spacing:.08em;color:#8b949e;margin-bottom:10px}
.scope-item{display:flex;align-items:center;gap:10px;padding:8px 0;border-bottom:1px solid #21262d;font-size:12.5px}
.scope-item:last-child{border-bottom:none}
.scope-item .ico{font-size:16px;flex-shrink:0}
.scope-item .desc{flex:1}.scope-item .desc .name{color:#c9d1d9;font-weight:600;font-size:12.5px}
.scope-item .desc .detail{color:#8b949e;font-size:11px;margin-top:1px}
.btn-row{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:4px}
.btn-allow{background:#238636;color:#fff;border:none;padding:10px;border-radius:6px;font-size:13px;font-weight:700;cursor:pointer}
.btn-deny{background:#21262d;color:#c9d1d9;border:1px solid #30363d;padding:10px;border-radius:6px;font-size:13px;cursor:pointer}
.meta{font-size:10px;color:#8b949e;text-align:center;margin-top:14px}
.meta a{color:#58a6ff}
</style></head>
<body>
<div class="card">
<div class="ch">
  <div class="scope-icon">⚡</div>
  <h2>Authorize Application</h2>
  <div class="app-name">PUL Monitoring Portal</div>
  <p>is requesting access to your PUL account</p>
</div>
<div class="cb">
<div class="scope-section">
<h3>This app will be able to:</h3>
<div class="scope-item"><span class="ico">👤</span><div class="desc"><div class="name">Read your profile</div><div class="detail">Name, email, employee ID, department</div></div></div>
<div class="scope-item"><span class="ico">📊</span><div class="desc"><div class="name">Access monitoring data</div><div class="detail">View grid metrics and alert states for your zone</div></div></div>
<div class="scope-item"><span class="ico">🔔</span><div class="desc"><div class="name">Send notifications</div><div class="detail">Create alerts and incidents on your behalf</div></div></div>
</div>
<div class="btn-row">
<button class="btn-allow" onclick="alert('OAuth session has been logged.')">Authorize</button>
<button class="btn-deny" onclick="alert('Request denied.')">Cancel</button>
</div>
<div class="meta">Authorizing redirects to <a>http://203.x.x.x:9090/oauth/callback</a><br>PUL OAuth 2.0 / OpenID Connect | sso.prabalurja.in</div>
</div>
</div>
</body></html>
HTML
cat > "${TRAP_DIR}/oauth/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m3-oauth.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,f,*a): logging.warning(f"HIT|src={self.client_address[0]}|path={self.path}")
    def do_GET(self):
        self.send_response(200);self.send_header("Content-Type","text/html");self.end_headers()
        with open(os.path.join(os.path.dirname(__file__),"index.html"),"rb") as f: self.wfile.write(f.read())
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0));b=self.rfile.read(n)
        logging.warning(f"POST|src={self.client_address[0]}|body={repr(b[:200])}")
        self.send_response(302);self.send_header("Location","/");self.end_headers()
http.server.HTTPServer(("0.0.0.0",8301),H).serve_forever()
PYEOF
make_svc "itgw-m3-oauth" "${TRAP_DIR}/oauth/server.py" 8301

# ─── D4: MFA / TOTP Admin Portal — port 8302 ──────────────────────────────────
mkdir -p "${TRAP_DIR}/mfa"
cat > "${TRAP_DIR}/mfa/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL MFA Admin</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#f5f3ff;color:#1e1b4b;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#4c1d95;border-bottom:3px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#e9d5ff;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.4);font-size:11px}
.main{flex:1;padding:20px;max-width:900px;margin:0 auto;width:100%}
.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px}
.kpi{background:#fff;border:1px solid #ede9fe;border-radius:7px;padding:14px;border-left:3px solid #7c3aed;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.kpi .n{font-size:24px;font-weight:800;color:#4c1d95}.kpi .l{font-size:11px;color:#718096;margin-top:3px;text-transform:uppercase;letter-spacing:.05em}
.kpi.ok .n{color:#059669}.kpi.warn .n{color:#d97706}
.panel{background:#fff;border:1px solid #ede9fe;border-radius:7px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.05);margin-bottom:14px}
.ph{background:#4c1d95;color:#e9d5ff;padding:10px 14px;font-size:12.5px;font-weight:600;border-bottom:2px solid #c4a53e}
.table{width:100%;border-collapse:collapse;font-size:12.5px}
.table th{background:#f5f3ff;padding:8px 14px;text-align:left;color:#718096;font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;border-bottom:1px solid #ede9fe}
.table td{padding:9px 14px;border-bottom:1px solid #f5f3ff;color:#1e1b4b}
.table tr:hover td{background:#faf5ff}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700}
.b-en{background:rgba(5,150,105,.12);color:#047857}.b-dis{background:rgba(107,114,128,.12);color:#374151}
.b-by{background:rgba(124,58,237,.12);color:#5b21b6}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:350px;overflow:hidden}
.lh{background:#4c1d95;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#e9d5ff;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#718096;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input{width:100%;padding:8px 10px;border:1px solid #ede9fe;border-radius:4px;font-size:13px}
.btn{width:100%;padding:9px;background:#4c1d95;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">🔑 MFA Admin Portal — Login</div>
<div class="lbody">
<div class="fg"><label>Admin Username</label><input type="text" placeholder="mfa-admin"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>🔑 PUL Multi-Factor Authentication Admin</h1><p>TOTP / FIDO2 Management | sso.prabalurja.in</p></div>
<div class="main">
<div class="kpis">
<div class="kpi ok"><div class="n">11,241</div><div class="l">MFA Enrolled</div></div>
<div class="kpi warn"><div class="n">2,600</div><div class="l">Not Enrolled</div></div>
<div class="kpi"><div class="n">48</div><div class="l">Bypass Active</div></div>
<div class="kpi"><div class="n">4</div><div class="l">Locked Out</div></div>
</div>
<div class="panel"><div class="ph">Recent MFA Events</div>
<table class="table">
<tr><th>User</th><th>Method</th><th>Event</th><th>Source IP</th><th>Time</th><th>Result</th></tr>
<tr><td>arun.sharma</td><td>TOTP</td><td>Verify</td><td>203.0.1.X</td><td>10:44 IST</td><td><span class="badge b-en">PASS</span></td></tr>
<tr><td>rajiv.menon</td><td>FIDO2</td><td>Verify</td><td>203.0.2.X</td><td>10:38 IST</td><td><span class="badge b-en">PASS</span></td></tr>
<tr><td>deepa.iyer</td><td>TOTP</td><td>Bypass</td><td>193.0.1.X</td><td>09:55 IST</td><td><span class="badge b-by">BYPASS</span></td></tr>
<tr><td>UNKNOWN</td><td>TOTP</td><td>Verify</td><td>203.0.1.Y</td><td>09:14 IST</td><td><span class="badge b-dis">FAIL ×3</span></td></tr>
</table></div></div>
</body></html>
HTML
cat > "${TRAP_DIR}/mfa/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m3-mfa.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,f,*a): logging.warning(f"HIT|src={self.client_address[0]}|path={self.path}")
    def do_GET(self):
        self.send_response(200);self.send_header("Content-Type","text/html");self.end_headers()
        with open(os.path.join(os.path.dirname(__file__),"index.html"),"rb") as f: self.wfile.write(f.read())
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0));b=self.rfile.read(n)
        logging.warning(f"POST|src={self.client_address[0]}|body={repr(b[:200])}")
        self.send_response(302);self.send_header("Location","/");self.end_headers()
http.server.HTTPServer(("0.0.0.0",8302),H).serve_forever()
PYEOF
make_svc "itgw-m3-mfa" "${TRAP_DIR}/mfa/server.py" 8302

# ─── D5: Identity Governance — port 8303 ──────────────────────────────────────
mkdir -p "${TRAP_DIR}/idgov"
cat > "${TRAP_DIR}/idgov/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Identity Governance</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#fff7ed;color:#1c1917;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#7c2d12;border-bottom:3px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#fed7aa;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.35);font-size:11px}
.main{flex:1;padding:20px;max-width:950px;margin:0 auto;width:100%}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:14px}
.panel{background:#fff;border:1px solid #fed7aa;border-radius:7px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.ph{background:#7c2d12;color:#fed7aa;padding:10px 14px;font-size:12.5px;font-weight:700;border-bottom:2px solid #c4a53e}
.pb{padding:14px}
.task-row{padding:9px 0;border-bottom:1px solid #fff7ed;display:flex;align-items:center;gap:10px;font-size:12.5px}
.task-row:last-child{border-bottom:none}
.task-row .name{flex:1;color:#1c1917}.task-row .owner{color:#9a3412;font-size:11.5px;width:120px}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700}
.b-pend{background:rgba(217,119,6,.12);color:#b45309}.b-app{background:rgba(5,150,105,.12);color:#047857}
.b-rev{background:rgba(124,58,237,.12);color:#5b21b6}.b-over{background:rgba(220,38,38,.12);color:#991b1b}
.access-row{padding:8px 0;border-bottom:1px solid #fff7ed;display:grid;grid-template-columns:160px 1fr 100px;gap:8px;font-size:12px}
.access-row:last-child{border-bottom:none}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:360px;overflow:hidden}
.lh{background:#7c2d12;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#fed7aa;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#9a3412;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input{width:100%;padding:8px 10px;border:1px solid #fed7aa;border-radius:4px;font-size:13px;background:#fff7ed}
.btn{width:100%;padding:9px;background:#7c2d12;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">🛂 Identity Governance — Login</div>
<div class="lbody">
<div class="fg"><label>Username</label><input type="text" placeholder="iam-admin or your username"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>🛂 PUL Identity Governance & Provisioning</h1><p>IAM | Access Certification | sso.prabalurja.in</p></div>
<div class="main">
<div class="grid2">
<div class="panel"><div class="ph">Pending Access Reviews</div><div class="pb">
<div class="task-row"><span class="name">cn=svc-cicd — privileged LDAP read</span><span class="owner">arun.sharma</span><span class="badge b-over">OVERDUE</span></div>
<div class="task-row"><span class="name">svc-deploy — Vault write access review</span><span class="owner">priya.nair</span><span class="badge b-pend">PENDING</span></div>
<div class="task-row"><span class="name">devops-admin — AWX admin role</span><span class="owner">priya.nair</span><span class="badge b-rev">IN REVIEW</span></div>
<div class="task-row"><span class="name">rajiv.menon — SOC full access</span><span class="owner">CISO</span><span class="badge b-app">APPROVED</span></div>
</div></div>
<div class="panel"><div class="ph">Recent Provisioning Events</div><div class="pb">
<div class="access-row"><span style="font-weight:600;color:#7c2d12">svc-monitor</span><span>Read access granted: secret/pul/* (Vault)</span><span class="badge b-app">DONE</span></div>
<div class="access-row"><span style="font-weight:600;color:#7c2d12">deepa.iyer</span><span>Grid Ops SCADA read role — provisioned</span><span class="badge b-app">DONE</span></div>
<div class="access-row"><span style="font-weight:600;color:#7c2d12">svc-cicd</span><span>Gitea repo pul-infra-config access</span><span class="badge b-app">DONE</span></div>
<div class="access-row"><span style="font-weight:600;color:#7c2d12">UNKNOWN</span><span>Failed auth ×5 — account locked</span><span class="badge b-over">ALERT</span></div>
</div></div>
</div></div>
</body></html>
HTML
cat > "${TRAP_DIR}/idgov/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m3-idgov.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,f,*a): logging.warning(f"HIT|src={self.client_address[0]}|path={self.path}")
    def do_GET(self):
        self.send_response(200);self.send_header("Content-Type","text/html");self.end_headers()
        with open(os.path.join(os.path.dirname(__file__),"index.html"),"rb") as f: self.wfile.write(f.read())
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0));b=self.rfile.read(n)
        logging.warning(f"POST|src={self.client_address[0]}|body={repr(b[:200])}")
        self.send_response(302);self.send_header("Location","/");self.end_headers()
http.server.HTTPServer(("0.0.0.0",8303),H).serve_forever()
PYEOF
make_svc "itgw-m3-idgov" "${TRAP_DIR}/idgov/server.py" 8303

# ─── D6: CyberArk PAM-style Privileged Access — port 8304 ────────────────────
mkdir -p "${TRAP_DIR}/pam"
cat > "${TRAP_DIR}/pam/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Privileged Access Manager</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#0c0c0c;color:#e0e0e0;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#1a0000;border-bottom:3px solid #c4a53e;padding:0 20px;height:56px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#c4a53e;font-size:15px;font-weight:700;display:flex;align-items:center;gap:8px}.hdr p{color:rgba(255,255,255,.35);font-size:11px}
.warn-bar{background:rgba(220,38,38,.1);border-bottom:1px solid rgba(220,38,38,.3);padding:6px 20px;font-size:11.5px;color:#f87171;display:flex;align-items:center;gap:8px}
.main{flex:1;display:flex;align-items:center;justify-content:center;padding:30px;flex-direction:column}
.login-card{background:#1a1a1a;border:1px solid #2d2d2d;border-radius:10px;width:420px;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.8)}
.lh{background:#1a0000;border-bottom:2px solid #c4a53e;padding:22px;text-align:center}
.lh .shield{font-size:44px;margin-bottom:8px}.lh h2{color:#c4a53e;font-size:16px;font-weight:700}
.lh p{color:rgba(255,255,255,.35);font-size:11px;margin-top:4px;letter-spacing:.05em;text-transform:uppercase}
.lb{padding:24px}
.fg{margin-bottom:16px}.fg label{display:block;font-size:10.5px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:rgba(255,255,255,.4);margin-bottom:5px}
.fg input{width:100%;padding:10px 14px;background:#0c0c0c;border:1.5px solid #2d2d2d;border-radius:6px;color:#e0e0e0;font-size:13px;outline:none}
.fg input:focus{border-color:#c4a53e}
.btn{width:100%;padding:11px;background:linear-gradient(135deg,#7f1d1d,#991b1b);color:#fff;border:none;border-radius:6px;font-size:13px;font-weight:800;letter-spacing:.05em;text-transform:uppercase;cursor:pointer}
.btn:hover{opacity:.9}
.pki-note{text-align:center;font-size:11px;color:rgba(255,255,255,.25);margin-top:14px}
</style></head>
<body>
<div class="hdr"><h1>🔒 PUL Privileged Access Manager</h1><p>CyberArk PAS 13.2 | Jump Server Proxy</p></div>
<div class="warn-bar">⚠ &nbsp;Restricted — All privileged access sessions are recorded and monitored. Unauthorised use is a criminal offence under IT Act 2000.</div>
<div class="main">
<div class="login-card">
<div class="lh"><div class="shield">🔒</div><h2>Privileged Access Portal</h2><p>Authentication Required — All Sessions Recorded</p></div>
<div class="lb">
<div class="fg"><label>Username</label><input type="text" placeholder="privileged account or PAM username"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="password"></div>
<div class="fg"><label>TOTP Code</label><input type="text" placeholder="6-digit OTP" maxlength="6"></div>
<button class="btn" onclick="alert('Authentication failed. Attempt has been recorded and will be reviewed.')">Authenticate & Connect</button>
<div class="pki-note">PKI Certificate authentication also supported | Contact SOC for enrolment</div>
</div>
</div>
</div>
</body></html>
HTML
cat > "${TRAP_DIR}/pam/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m3-pam.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,f,*a): logging.warning(f"HIT|src={self.client_address[0]}|path={self.path}")
    def do_GET(self):
        self.send_response(200);self.send_header("Content-Type","text/html");self.end_headers()
        with open(os.path.join(os.path.dirname(__file__),"index.html"),"rb") as f: self.wfile.write(f.read())
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0));b=self.rfile.read(n)
        logging.warning(f"POST|src={self.client_address[0]}|body={repr(b[:200])}")
        self.send_response(302);self.send_header("Location","/");self.end_headers()
http.server.HTTPServer(("0.0.0.0",8304),H).serve_forever()
PYEOF
make_svc "itgw-m3-pam" "${TRAP_DIR}/pam/server.py" 8304

# ─── D7: SSO Federation Metadata Viewer — port 8305 ──────────────────────────
mkdir -p "${TRAP_DIR}/fedmeta"
cat > "${TRAP_DIR}/fedmeta/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL SSO Federation Metadata</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:monospace,'Segoe UI',Arial;background:#1a1a2e;color:#e0e0e0;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#16213e;border-bottom:2px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#c4a53e;font-size:14px;font-weight:700}.hdr p{color:rgba(255,255,255,.35);font-size:11px}
.main{flex:1;padding:20px;max-width:900px;margin:0 auto;width:100%}
.panel{background:#16213e;border:1px solid #0f3460;border-radius:6px;overflow:hidden;margin-bottom:14px}
.ph{background:#0f3460;border-bottom:1px solid #16213e;padding:10px 14px;font-size:12px;font-weight:600;color:#c4a53e}
.pb{padding:14px}
.meta-row{display:flex;gap:12px;padding:8px 0;border-bottom:1px solid #0f3460;font-size:11.5px}
.meta-row:last-child{border-bottom:none}
.mk{width:200px;flex-shrink:0;color:#9197a3}.mv{flex:1;color:#64ffda;word-break:break-all}
.mv.plain{color:#e0e0e0}
.xml-block{background:#0d1117;border:1px solid #30363d;border-radius:4px;padding:12px;font-size:10.5px;color:#3fb950;overflow-x:auto;white-space:pre;line-height:1.6;max-height:200px;overflow-y:auto}
.login{position:fixed;inset:0;background:rgba(0,0,0,.7);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#16213e;border:1px solid #0f3460;border-radius:6px;width:360px;overflow:hidden}
.lh{background:#0f3460;border-bottom:1px solid #16213e;padding:14px;color:#c4a53e;font-size:13px;font-weight:700}
.lbody{padding:16px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10px;color:#9197a3;text-transform:uppercase;letter-spacing:.07em;margin-bottom:4px}
.fg input{width:100%;padding:8px 10px;background:#0d1117;border:1px solid #0f3460;border-radius:4px;color:#e0e0e0;font-size:12px;outline:none}
.btn{width:100%;padding:9px;background:#c4a53e;color:#0d1117;border:none;border-radius:4px;font-size:13px;font-weight:800;cursor:pointer}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">📋 Federation Metadata — Admin View</div>
<div class="lbody">
<div class="fg"><label>Username</label><input type="text" placeholder="sso-admin"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Authenticate</button>
</div></div></div>
<div class="hdr"><h1>📋 PUL SSO Federation Metadata Manager</h1><p>SAML 2.0 / OpenID Connect | sso.prabalurja.in</p></div>
<div class="main">
<div class="panel"><div class="ph">IdP Metadata Endpoints</div><div class="pb">
<div class="meta-row"><span class="mk">SAML Metadata URL</span><span class="mv">https://sso.prabalurja.in/saml/idp/metadata</span></div>
<div class="meta-row"><span class="mk">OIDC Discovery</span><span class="mv">https://sso.prabalurja.in/.well-known/openid-configuration</span></div>
<div class="meta-row"><span class="mk">JWKS URI</span><span class="mv">https://sso.prabalurja.in/.well-known/jwks.json</span></div>
<div class="meta-row"><span class="mk">Token Endpoint</span><span class="mv">https://sso.prabalurja.in/oauth/token</span></div>
<div class="meta-row"><span class="mk">Userinfo Endpoint</span><span class="mv">https://sso.prabalurja.in/oauth/userinfo</span></div>
</div></div>
<div class="panel"><div class="ph">SAML Metadata XML (IdP)</div><div class="pb">
<div class="xml-block">&lt;?xml version="1.0"?&gt;
&lt;EntityDescriptor entityID="https://sso.prabalurja.in/saml/idp"
    xmlns="urn:oasis:names:tc:SAML:2.0:metadata"&gt;
  &lt;IDPSSODescriptor WantAuthnRequestsSigned="false"
      protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol"&gt;
    &lt;KeyDescriptor use="signing"&gt;
      &lt;ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#"&gt;
        &lt;ds:X509Data&gt;
          &lt;ds:X509Certificate&gt;MIICXDCCAUQCCQDpul2024signing...&lt;/ds:X509Certificate&gt;
        &lt;/ds:X509Data&gt;
      &lt;/ds:KeyInfo&gt;
    &lt;/KeyDescriptor&gt;
    &lt;SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
        Location="https://sso.prabalurja.in/saml/sso/post"/&gt;
    &lt;SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
        Location="https://sso.prabalurja.in/saml/sso/redirect"/&gt;
  &lt;/IDPSSODescriptor&gt;
&lt;/EntityDescriptor&gt;</div>
</div></div></div>
</body></html>
HTML
cat > "${TRAP_DIR}/fedmeta/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m3-fedmeta.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,f,*a): logging.warning(f"HIT|src={self.client_address[0]}|path={self.path}")
    def do_GET(self):
        self.send_response(200);self.send_header("Content-Type","text/html");self.end_headers()
        with open(os.path.join(os.path.dirname(__file__),"index.html"),"rb") as f: self.wfile.write(f.read())
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0));b=self.rfile.read(n)
        logging.warning(f"POST|src={self.client_address[0]}|body={repr(b[:200])}")
        self.send_response(302);self.send_header("Location","/");self.end_headers()
http.server.HTTPServer(("0.0.0.0",8305),H).serve_forever()
PYEOF
make_svc "itgw-m3-fedmeta" "${TRAP_DIR}/fedmeta/server.py" 8305

echo ""
echo "============================================================"
echo "  RNG-IT-01 | M3 itgw-sso — Honeytraps Active"
echo "  D1: LDAPS banner (socket)    → port 8636"
echo "  D2: SAML IdP Console         → port 8300"
echo "  D3: OAuth Authorization Srv  → port 8301"
echo "  D4: MFA / TOTP Admin         → port 8302"
echo "  D5: Identity Governance      → port 8303"
echo "  D6: PAM / CyberArk-style     → port 8304"
echo "  D7: SSO Federation Metadata  → port 8305"
echo "  Logs: ${LOG_DIR}/itgw-m3-*.log"
echo "============================================================"
