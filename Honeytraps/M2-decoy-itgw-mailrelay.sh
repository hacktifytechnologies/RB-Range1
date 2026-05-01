#!/usr/bin/env bash
# =============================================================================
# RNG-IT-01 | M2 — itgw-mailrelay | Honeytraps (7 decoys)
# Ports:
#   8025  — SMTP banner (socket)
#   8110  — POP3 banner (socket)
#   8250  — Roundcube Webmail (web)
#   8251  — Email Archive & eDiscovery (web)
#   8252  — Anti-spam / Email Security Gateway (web)
#   8253  — DKIM/DMARC Management Console (web)
#   8254  — Mailing List Manager (web)
# =============================================================================
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "[!] Must be run as root." >&2; exit 1; fi
TRAP_DIR="/opt/pul-honeytrap/itgw-m2"; LOG_DIR="/var/log/pul-honeytrap"
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

# ─── D1: SMTP Banner — port 8025 ──────────────────────────────────────────────
cat > "${TRAP_DIR}/smtp-banner.py" << 'PYEOF'
#!/usr/bin/env python3
import socket,threading,logging,os
LOG="/var/log/pul-honeytrap/itgw-m2-smtp.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
BANNER=b"220 mail-relay01.prabalurja.in ESMTP Postfix (Ubuntu) ready\r\n"
def handle(conn,addr):
    logging.warning(f"SMTP_CONNECT|src={addr[0]}")
    try:
        conn.sendall(BANNER)
        data=conn.recv(512)
        if data: logging.warning(f"SMTP_DATA|src={addr[0]}|data={repr(data[:100])}")
        if b"EHLO" in data.upper() or b"HELO" in data.upper():
            conn.sendall(b"250-mail-relay01.prabalurja.in\r\n250-SIZE 52428800\r\n250-STARTTLS\r\n250-AUTH LOGIN PLAIN\r\n250 OK\r\n")
            more=conn.recv(512)
            if more: logging.warning(f"SMTP_CMD|src={addr[0]}|cmd={repr(more[:100])}")
        conn.sendall(b"421 Service temporarily unavailable.\r\n")
    except: pass
    finally: conn.close()
srv=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
srv.bind(("0.0.0.0",8025));srv.listen(10)
while True:
    c,a=srv.accept()
    threading.Thread(target=handle,args=(c,a),daemon=True).start()
PYEOF
make_svc "itgw-m2-smtp" "${TRAP_DIR}/smtp-banner.py" 8025

# ─── D2: POP3 Banner — port 8110 ──────────────────────────────────────────────
cat > "${TRAP_DIR}/pop3-banner.py" << 'PYEOF'
#!/usr/bin/env python3
import socket,threading,logging
LOG="/var/log/pul-honeytrap/itgw-m2-pop3.log"
logging.basicConfig(filename=LOG,level=logging.WARNING,format="%(asctime)s %(message)s")
BANNER=b"+OK PUL POP3 server mail-relay01.prabalurja.in ready <timestamp.pid@prabalurja.in>\r\n"
def handle(conn,addr):
    logging.warning(f"POP3_CONNECT|src={addr[0]}")
    try:
        conn.sendall(BANNER)
        data=conn.recv(256)
        if data: logging.warning(f"POP3_DATA|src={addr[0]}|data={repr(data[:80])}")
        conn.sendall(b"-ERR Authentication failed\r\n")
    except: pass
    finally: conn.close()
srv=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
srv.bind(("0.0.0.0",8110));srv.listen(10)
while True:
    c,a=srv.accept()
    threading.Thread(target=handle,args=(c,a),daemon=True).start()
PYEOF
make_svc "itgw-m2-pop3" "${TRAP_DIR}/pop3-banner.py" 8110

# ─── D3: Roundcube Webmail — port 8250 ────────────────────────────────────────
mkdir -p "${TRAP_DIR}/webmail"
cat > "${TRAP_DIR}/webmail/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Webmail</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:Arial,'Segoe UI',sans-serif;background:#e5e5e5;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#1aa3e8;padding:12px 24px;display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid #c4a53e}
.hdr .brand{color:#fff;font-size:18px;font-weight:700;letter-spacing:.02em}
.hdr .sub{color:rgba(255,255,255,.6);font-size:12px}
.main{flex:1;display:flex;align-items:center;justify-content:center;padding:30px}
.login-card{background:#fff;border-radius:6px;width:400px;box-shadow:0 4px 20px rgba(0,0,0,.12)}
.lh{background:#1a3a5c;border-radius:6px 6px 0 0;border-bottom:2px solid #c4a53e;padding:18px 22px;text-align:center}
.lh .icon{font-size:36px;margin-bottom:6px}.lh h2{color:#fff;font-size:16px;font-weight:700}
.lh p{color:rgba(255,255,255,.45);font-size:11px;margin-top:3px;letter-spacing:.04em;text-transform:uppercase}
.lb{padding:22px}
.fg{margin-bottom:14px}.fg label{display:block;font-size:11px;color:#888;margin-bottom:4px;font-weight:600;text-transform:uppercase;letter-spacing:.06em}
.fg input{width:100%;padding:9px 12px;border:1px solid #ddd;border-radius:4px;font-size:14px}
.fg input:focus{outline:none;border-color:#1aa3e8}
.opts{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;font-size:12px;color:#888}
.btn{width:100%;padding:10px;background:#1aa3e8;color:#fff;border:none;border-radius:4px;font-size:14px;font-weight:700;cursor:pointer}
.btn:hover{background:#1490cc}
.footer{text-align:center;font-size:10.5px;color:#bbb;margin-top:14px}
.topbar{background:#1a3a5c;padding:5px 24px;font-size:10.5px;color:rgba(255,255,255,.3);display:flex;justify-content:space-between}
</style></head>
<body>
<div class="topbar"><span>🇮🇳 Prabal Urja Limited — Enterprise Webmail</span><span>mail-relay01.prabalurja.in | Secure Connection</span></div>
<div class="hdr"><div class="brand">PUL Webmail</div><div class="sub">Powered by Roundcube | Enterprise Edition</div></div>
<div class="main"><div class="login-card">
<div class="lh"><div class="icon">✉️</div><h2>Sign In to Webmail</h2><p>prabalurja.in mail services</p></div>
<div class="lb">
<div class="fg"><label>Email Address</label><input type="text" placeholder="name@prabalurja.in"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Email password"></div>
<div class="opts"><label><input type="checkbox"> Remember me</label><a href="#" style="color:#1aa3e8">Forgot password?</a></div>
<button class="btn" onclick="alert('Authentication failed. Invalid email or password.')">Sign In</button>
<div class="footer">Roundcube 1.6.4 | © 2024 Prabal Urja Limited</div>
</div></div></div>
</body></html>
HTML
cat > "${TRAP_DIR}/webmail/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m2-webmail.log"
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
http.server.HTTPServer(("0.0.0.0",8250),H).serve_forever()
PYEOF
make_svc "itgw-m2-webmail" "${TRAP_DIR}/webmail/server.py" 8250

# ─── D4: Email Archive / eDiscovery — port 8251 ───────────────────────────────
mkdir -p "${TRAP_DIR}/mailarchive"
cat > "${TRAP_DIR}/mailarchive/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Mail Archive</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#1a1a2e;color:#c9d1d9;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#16213e;border-bottom:2px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#c4a53e;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.35);font-size:11px}
.main{flex:1;padding:20px;max-width:900px;margin:0 auto;width:100%}
.panel{background:#161b22;border:1px solid #21262d;border-radius:8px;overflow:hidden;margin-bottom:14px}
.ph{background:#21262d;border-bottom:1px solid #30363d;padding:10px 14px;font-size:12px;font-weight:600;color:#c4a53e}
.pb{padding:14px}
.search-bar{display:flex;gap:8px;margin-bottom:16px}
.search-bar input{flex:1;padding:9px 12px;background:#0d1117;border:1px solid #30363d;border-radius:5px;color:#c9d1d9;font-size:13px;outline:none}
.search-bar input:focus{border-color:#c4a53e}
.search-bar button{background:#c4a53e;color:#0d1117;border:none;padding:9px 18px;border-radius:5px;font-size:12px;font-weight:700;cursor:pointer}
.stat-row{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:16px}
.stat{background:#0d1117;border:1px solid #21262d;border-radius:6px;padding:12px;text-align:center}
.stat .n{font-size:22px;font-weight:800;color:#58a6ff}.stat .l{font-size:10.5px;color:#8b949e;margin-top:2px;text-transform:uppercase}
.msg-row{display:flex;align-items:center;gap:10px;padding:8px 0;border-bottom:1px solid #21262d;font-size:12.5px}
.msg-row:last-child{border-bottom:none}.msg-from{width:180px;flex-shrink:0;color:#c9d1d9}.msg-sub{flex:1;color:#8b949e}.msg-date{font-size:11px;color:#8b949e;width:100px;text-align:right}
.login{position:fixed;inset:0;background:rgba(0,0,0,.7);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#161b22;border:1px solid #30363d;border-radius:8px;width:360px;overflow:hidden}
.lh{background:#21262d;border-bottom:1px solid #30363d;padding:14px;color:#c4a53e;font-size:13px;font-weight:700}
.lbody{padding:16px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10px;color:#8b949e;text-transform:uppercase;letter-spacing:.07em;margin-bottom:4px}
.fg input{width:100%;padding:8px 10px;background:#0d1117;border:1px solid #30363d;border-radius:4px;color:#c9d1d9;font-size:13px;outline:none}
.btn{width:100%;padding:9px;background:#c4a53e;color:#0d1117;border:none;border-radius:4px;font-size:13px;font-weight:800;cursor:pointer}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">📬 Mail Archive — Compliance Login</div>
<div class="lbody">
<div class="fg"><label>Username</label><input type="text" placeholder="compliance officer or admin"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Authenticate</button>
</div></div></div>
<div class="hdr"><h1>📬 PUL Email Archive & eDiscovery</h1><p>Compliance & Legal Hold | mail-relay01.prabalurja.in</p></div>
<div class="main">
<div class="stat-row">
<div class="stat"><div class="n">4.2M</div><div class="l">Archived Emails</div></div>
<div class="stat"><div class="n">12</div><div class="l">Active Legal Holds</div></div>
<div class="stat"><div class="n">847 GB</div><div class="l">Archive Size</div></div>
</div>
<div class="panel"><div class="ph">eDiscovery Search</div><div class="pb">
<div class="search-bar"><input type="text" placeholder="Search by sender, subject, date range, keywords..."><button>Search Archive</button></div>
</div></div>
<div class="panel"><div class="ph">Recent Legal Hold Emails (Sample)</div><div class="pb">
<div class="msg-row"><span class="msg-from">arun.sharma@prabalurja.in</span><span class="msg-sub">Re: Vault configuration — urgent</span><span class="msg-date">Nov 14, 2024</span></div>
<div class="msg-row"><span class="msg-from">priya.nair@prabalurja.in</span><span class="msg-sub">AWX verbose logging policy — review</span><span class="msg-date">Nov 12, 2024</span></div>
<div class="msg-row"><span class="msg-from">rajiv.menon@prabalurja.in</span><span class="msg-sub">CERT-In audit — LDAP ACL findings</span><span class="msg-date">Nov 10, 2024</span></div>
<div class="msg-row"><span class="msg-from">svc-cicd@prabalurja.in</span><span class="msg-sub">Automated: Pipeline failure — Vault token expired</span><span class="msg-date">Nov 14, 2024</span></div>
</div></div></div>
</body></html>
HTML
cat > "${TRAP_DIR}/mailarchive/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m2-mailarchive.log"
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
http.server.HTTPServer(("0.0.0.0",8251),H).serve_forever()
PYEOF
make_svc "itgw-m2-mailarchive" "${TRAP_DIR}/mailarchive/server.py" 8251

# ─── D5: Anti-spam / Email Security Gateway — port 8252 ───────────────────────
mkdir -p "${TRAP_DIR}/antispam"
cat > "${TRAP_DIR}/antispam/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Email Security Gateway</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#f4f6f9;color:#2d3748;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#7b2d8b;border-bottom:3px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#e9d5f5;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.4);font-size:11px}
.main{flex:1;padding:20px;max-width:1050px;margin:0 auto;width:100%}
.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:20px}
.kpi{background:#fff;border:1px solid #e2e8f0;border-radius:7px;padding:14px;border-left:3px solid #7b2d8b;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.kpi .n{font-size:24px;font-weight:800;color:#7b2d8b}.kpi .l{font-size:11px;color:#718096;margin-top:3px;text-transform:uppercase;letter-spacing:.05em}
.kpi.ok .n{color:#059669}.kpi.warn .n{color:#d97706}
.panel{background:#fff;border:1px solid #e2e8f0;border-radius:7px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.ph{background:#7b2d8b;color:#e9d5f5;padding:10px 14px;font-size:12.5px;font-weight:600;border-bottom:2px solid #c4a53e}
.table{width:100%;border-collapse:collapse;font-size:12.5px}
.table th{background:#faf5ff;padding:8px 14px;text-align:left;color:#718096;font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;border-bottom:1px solid #e2e8f0}
.table td{padding:9px 14px;border-bottom:1px solid #faf5ff;color:#2d3748}
.table tr:hover td{background:#fdf4ff}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700}
.b-spam{background:rgba(220,38,38,.12);color:#991b1b}.b-clean{background:rgba(5,150,105,.12);color:#047857}
.b-phish{background:rgba(234,88,12,.12);color:#9a3412}.b-suspect{background:rgba(217,119,6,.12);color:#b45309}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:350px;overflow:hidden}
.lh{background:#7b2d8b;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#e9d5f5;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#718096;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input{width:100%;padding:8px 10px;border:1px solid #e2e8f0;border-radius:4px;font-size:13px}
.btn{width:100%;padding:9px;background:#7b2d8b;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">🛡 Email Security Gateway — Admin Login</div>
<div class="lbody">
<div class="fg"><label>Username</label><input type="text" placeholder="admin or postmaster"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>🛡 PUL Email Security Gateway</h1><p>Anti-spam & Anti-phishing Console | mail-relay01.prabalurja.in</p></div>
<div class="main">
<div class="grid3">
<div class="kpi warn"><div class="n">2,847</div><div class="l">Emails Scanned Today</div></div>
<div class="kpi"><div class="n">487</div><div class="l">Spam Blocked</div></div>
<div class="kpi ok"><div class="n">12</div><div class="l">Phishing Quarantined</div></div>
</div>
<div class="panel">
<div class="ph">Recent Quarantine Log</div>
<table class="table">
<tr><th>Time</th><th>Sender</th><th>Recipient</th><th>Subject</th><th>Classification</th><th>Score</th></tr>
<tr><td style="font-size:11px">10:47 IST</td><td style="font-family:monospace;font-size:11px">noreply@prabalurja-secure.in</td><td>arun.sharma</td><td>Urgent: VPN Credential Reset Required</td><td><span class="badge b-phish">PHISHING</span></td><td>9.4</td></tr>
<tr><td style="font-size:11px">09:33 IST</td><td style="font-family:monospace;font-size:11px">support@microsoft-india.co</td><td>all-staff</td><td>Your Office 365 license expires today</td><td><span class="badge b-spam">SPAM</span></td><td>7.8</td></tr>
<tr><td style="font-size:11px">08:14 IST</td><td style="font-family:monospace;font-size:11px">invoice@vendor-prabal.com</td><td>finance</td><td>Invoice #INV-2024-9871 — Payment Due</td><td><span class="badge b-suspect">SUSPECT</span></td><td>5.2</td></tr>
<tr><td style="font-size:11px">07:02 IST</td><td style="font-family:monospace;font-size:11px">rajiv.menon@prabalurja.in</td><td>soc-team</td><td>CERT-In Audit Update — Action Required</td><td><span class="badge b-clean">CLEAN</span></td><td>0.1</td></tr>
</table></div></div>
</body></html>
HTML
cat > "${TRAP_DIR}/antispam/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m2-antispam.log"
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
http.server.HTTPServer(("0.0.0.0",8252),H).serve_forever()
PYEOF
make_svc "itgw-m2-antispam" "${TRAP_DIR}/antispam/server.py" 8252

# ─── D6: DKIM/DMARC Management Console — port 8253 ────────────────────────────
mkdir -p "${TRAP_DIR}/dkim"
cat > "${TRAP_DIR}/dkim/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL DKIM/DMARC Console</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',monospace,Arial;background:#0d1117;color:#c9d1d9;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#161b22;border-bottom:2px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#c4a53e;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.35);font-size:11px}
.main{flex:1;padding:20px;max-width:900px;margin:0 auto;width:100%}
.panel{background:#161b22;border:1px solid #21262d;border-radius:8px;overflow:hidden;margin-bottom:14px}
.ph{background:#21262d;border-bottom:1px solid #30363d;padding:10px 14px;font-size:12px;font-weight:600;color:#c4a53e}
.pb{padding:14px}
.row{display:flex;align-items:flex-start;gap:12px;padding:10px 0;border-bottom:1px solid #21262d;font-size:12.5px}
.row:last-child{border-bottom:none}
.row .key{width:140px;flex-shrink:0;color:#8b949e;font-size:11.5px;text-transform:uppercase;letter-spacing:.05em}
.row .val{flex:1;font-family:'Courier New',monospace;font-size:11.5px;color:#3fb950;word-break:break-all}
.row .val.warn{color:#f59e0b}.row .val.ok{color:#3fb950}.row .val.err{color:#f85149}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700;margin-left:8px}
.b-pass{background:rgba(63,185,80,.15);color:#3fb950}.b-fail{background:rgba(248,81,73,.15);color:#f85149}
.b-warn{background:rgba(245,158,11,.15);color:#f59e0b}
.login{position:fixed;inset:0;background:rgba(0,0,0,.7);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#161b22;border:1px solid #30363d;border-radius:8px;width:360px;overflow:hidden}
.lh{background:#21262d;border-bottom:1px solid #30363d;padding:14px;color:#c4a53e;font-size:13px;font-weight:700}
.lbody{padding:16px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10px;color:#8b949e;text-transform:uppercase;letter-spacing:.07em;margin-bottom:4px}
.fg input{width:100%;padding:8px 10px;background:#0d1117;border:1px solid #30363d;border-radius:4px;color:#c9d1d9;font-size:12px;outline:none}
.btn{width:100%;padding:9px;background:#c4a53e;color:#0d1117;border:none;border-radius:4px;font-size:13px;font-weight:800;cursor:pointer}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">🔑 DKIM/DMARC Console — Authentication</div>
<div class="lbody">
<div class="fg"><label>Username</label><input type="text" placeholder="postmaster or admin"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Authenticate</button>
</div></div></div>
<div class="hdr"><h1>🔑 PUL DKIM/DMARC Management</h1><p>Email Authentication Console | mail-relay01.prabalurja.in</p></div>
<div class="main">
<div class="panel"><div class="ph">DKIM Keys — prabalurja.in</div><div class="pb">
<div class="row"><span class="key">Selector</span><span class="val">pul-2024-nov._domainkey.prabalurja.in</span></div>
<div class="row"><span class="key">Key Type</span><span class="val ok">RSA-2048 <span class="badge b-pass">VALID</span></span></div>
<div class="row"><span class="key">Public Key</span><span class="val" style="font-size:10px">v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA[...truncated for display]</span></div>
<div class="row"><span class="key">Expiry</span><span class="val warn">2025-01-15 (62 days) <span class="badge b-warn">ROTATION DUE</span></span></div>
<div class="row"><span class="key">Signing Mode</span><span class="val ok">relaxed/relaxed</span></div>
</div></div>
<div class="panel"><div class="ph">DMARC Policy — prabalurja.in</div><div class="pb">
<div class="row"><span class="key">Record</span><span class="val" style="font-size:10px">v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@prabalurja.in; ruf=mailto:dmarc-forensic@prabalurja.in; pct=100; adkim=s; aspf=s;</span></div>
<div class="row"><span class="key">Policy</span><span class="val warn">quarantine (recommend: reject) <span class="badge b-warn">REVIEW</span></span></div>
<div class="row"><span class="key">SPF Alignment</span><span class="val ok">PASS <span class="badge b-pass">ALIGNED</span></span></div>
<div class="row"><span class="key">Reports</span><span class="val ok">Last received: 2024-11-15 00:00 IST</span></div>
</div></div></div>
</body></html>
HTML
cat > "${TRAP_DIR}/dkim/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m2-dkim.log"
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
http.server.HTTPServer(("0.0.0.0",8253),H).serve_forever()
PYEOF
make_svc "itgw-m2-dkim" "${TRAP_DIR}/dkim/server.py" 8253

# ─── D7: Mailing List Manager — port 8254 ─────────────────────────────────────
mkdir -p "${TRAP_DIR}/mailman"
cat > "${TRAP_DIR}/mailman/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Mailing List Manager</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:Arial,'Segoe UI',sans-serif;background:#f0f4f8;color:#333;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#34495e;border-bottom:3px solid #c4a53e;padding:10px 20px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#ecf0f1;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.4);font-size:11px}
.main{flex:1;padding:20px;max-width:860px;margin:0 auto;width:100%}
.list-card{background:#fff;border:1px solid #ddd;border-radius:6px;padding:16px;margin-bottom:10px;display:flex;align-items:center;justify-content:space-between;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.list-card .info .name{font-size:14px;font-weight:700;color:#2c3e50;margin-bottom:3px}
.list-card .info .addr{font-family:monospace;font-size:12px;color:#34495e;margin-bottom:3px}
.list-card .info .desc{font-size:12px;color:#888}
.list-card .stats{text-align:right;flex-shrink:0;margin-left:20px}
.list-card .stats .members{font-size:18px;font-weight:800;color:#34495e}.list-card .stats .label{font-size:10px;color:#aaa;text-transform:uppercase}
.btn-sub{background:#34495e;color:#fff;border:none;padding:7px 14px;border-radius:4px;font-size:12px;cursor:pointer;margin-top:6px}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:6px;width:340px;overflow:hidden}
.lh{background:#34495e;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#ecf0f1;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#888;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input{width:100%;padding:8px 10px;border:1px solid #ddd;border-radius:4px;font-size:13px}
.btn{width:100%;padding:9px;background:#34495e;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer}
.section-hdr{font-size:12px;font-weight:700;color:#34495e;text-transform:uppercase;letter-spacing:.08em;margin-bottom:12px;border-bottom:1px solid #ddd;padding-bottom:6px}
.footer{background:#34495e;padding:8px 20px;text-align:center;font-size:10px;color:rgba(255,255,255,.25)}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">📧 Mailing List Admin — Sign In</div>
<div class="lbody">
<div class="fg"><label>Admin Email</label><input type="text" placeholder="postmaster@prabalurja.in"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="List admin password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>📧 PUL Mailing List Manager</h1><p>GNU Mailman 3 | mail-relay01.prabalurja.in</p></div>
<div class="main">
<div class="section-hdr">Active Mailing Lists (prabalurja.in)</div>
<div class="list-card"><div class="info"><div class="name">All Staff</div><div class="addr">all-staff@prabalurja.in</div><div class="desc">Company-wide announcements and communications</div></div><div class="stats"><div class="members">13,841</div><div class="label">Members</div><button class="btn-sub" onclick="alert('Subscription changes require admin approval.')">Manage</button></div></div>
<div class="list-card"><div class="info"><div class="name">IT Operations</div><div class="addr">it-ops@prabalurja.in</div><div class="desc">IT Operations team — internal coordination</div></div><div class="stats"><div class="members">47</div><div class="label">Members</div><button class="btn-sub" onclick="alert('Restricted list.')">Manage</button></div></div>
<div class="list-card"><div class="info"><div class="name">SOC Alerts</div><div class="addr">soc-alerts@prabalurja.in</div><div class="desc">Security Operations Centre — automated alerts and advisories</div></div><div class="stats"><div class="members">12</div><div class="label">Members</div><button class="btn-sub" onclick="alert('Restricted list.')">Manage</button></div></div>
<div class="list-card"><div class="info"><div class="name">Grid Operations</div><div class="addr">grid-ops@prabalurja.in</div><div class="desc">Grid Operations team — shift handover and incident notifications</div></div><div class="stats"><div class="members">284</div><div class="label">Members</div><button class="btn-sub" onclick="alert('Restricted list.')">Manage</button></div></div>
</div>
<div class="footer">© 2024 Prabal Urja Limited | Mailing List Manager | GNU Mailman 3.3.9</div>
</body></html>
HTML
cat > "${TRAP_DIR}/mailman/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m2-mailman.log"
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
http.server.HTTPServer(("0.0.0.0",8254),H).serve_forever()
PYEOF
make_svc "itgw-m2-mailman" "${TRAP_DIR}/mailman/server.py" 8254

echo ""
echo "============================================================"
echo "  RNG-IT-01 | M2 itgw-mailrelay — Honeytraps Active"
echo "  D1: SMTP banner (socket) → port 8025"
echo "  D2: POP3 banner (socket) → port 8110"
echo "  D3: Roundcube Webmail    → port 8250"
echo "  D4: Email Archive/eDisc  → port 8251"
echo "  D5: Anti-spam Gateway    → port 8252"
echo "  D6: DKIM/DMARC Console   → port 8253"
echo "  D7: Mailing List Manager → port 8254"
echo "  Logs: ${LOG_DIR}/itgw-m2-*.log"
echo "============================================================"
