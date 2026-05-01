#!/usr/bin/env bash
# =============================================================================
# RNG-IT-01 | M1 — itgw-webportal | Honeytraps (7 decoys)
# Ports:
#   2121  — FTP banner (socket)
#   8090  — Employee Self-Service Portal (web)
#   8181  — IT Helpdesk / Ticketing System (web)
#   8282  — Document Management System (web)
#   8383  — Corporate Asset Inventory (web)
#   8484  — Visitor Management System (web)
#   8585  — Corporate Intranet / Announcements (web)
# =============================================================================
set -euo pipefail
if [[ $EUID -ne 0 ]]; then echo "[!] Must be run as root." >&2; exit 1; fi

TRAP_DIR="/opt/pul-honeytrap/itgw-m1"
LOG_DIR="/var/log/pul-honeytrap"
mkdir -p "${TRAP_DIR}" "${LOG_DIR}"

# ─── Helper ───────────────────────────────────────────────────────────────────
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

# ─── D1: FTP Banner — port 2121 ───────────────────────────────────────────────
cat > "${TRAP_DIR}/ftp-banner.py" << 'PYEOF'
#!/usr/bin/env python3
import socket, threading, logging, os
LOG = "/var/log/pul-honeytrap/itgw-m1-ftp.log"
logging.basicConfig(filename=LOG, level=logging.WARNING, format="%(asctime)s %(message)s")
BANNER = b"220 PUL-FTP-SRV01 FTP Server (FileZilla Server 1.7.3) ready.\r\n"
def handle(conn, addr):
    logging.warning(f"FTP_CONNECT|src={addr[0]}")
    try:
        conn.sendall(BANNER)
        data = conn.recv(256)
        if data: logging.warning(f"FTP_DATA|src={addr[0]}|data={repr(data[:80])}")
        conn.sendall(b"530 Login incorrect.\r\n")
    except: pass
    finally: conn.close()
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("0.0.0.0", 2121)); srv.listen(10)
while True:
    c, a = srv.accept()
    threading.Thread(target=handle, args=(c, a), daemon=True).start()
PYEOF
chmod +x "${TRAP_DIR}/ftp-banner.py"
make_svc "itgw-m1-ftp" "${TRAP_DIR}/ftp-banner.py" 2121

# ─── D2: Employee Self-Service Portal — port 8090 ─────────────────────────────
mkdir -p "${TRAP_DIR}/ess"
cat > "${TRAP_DIR}/ess/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Employee Self-Service</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#f0f4f8;color:#1a202c;min-height:100vh;display:flex;flex-direction:column}
.topbar{background:#0d1b2a;border-bottom:2px solid #c4a53e;padding:8px 24px;display:flex;align-items:center;justify-content:space-between}
.topbar .brand{color:#c4a53e;font-weight:800;font-size:15px;letter-spacing:.03em}
.topbar .meta{color:rgba(255,255,255,.35);font-size:11px}
.hero{background:linear-gradient(135deg,#0d1b2a,#1a3a5c);color:#fff;padding:40px 24px;text-align:center}
.hero h1{font-size:22px;font-weight:700;color:#c4a53e;margin-bottom:8px}
.hero p{color:rgba(255,255,255,.55);font-size:13px}
.main{flex:1;padding:24px;max-width:800px;margin:0 auto;width:100%}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-top:20px}
.card{background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:20px;text-align:center;cursor:pointer;transition:all .15s;box-shadow:0 1px 4px rgba(0,0,0,.05)}
.card:hover{border-color:#c4a53e;box-shadow:0 4px 12px rgba(0,0,0,.1);transform:translateY(-2px)}
.card .icon{font-size:32px;margin-bottom:10px}
.card h3{font-size:13px;font-weight:700;color:#1a202c;margin-bottom:4px}
.card p{font-size:11px;color:#718096}
.login-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);display:flex;align-items:center;justify-content:center;z-index:99}
.login-box{background:#fff;border-radius:10px;width:380px;overflow:hidden;box-shadow:0 20px 50px rgba(0,0,0,.3)}
.lh{background:#0d1b2a;border-bottom:2px solid #c4a53e;padding:18px 20px;color:#c4a53e;font-weight:700;font-size:14px}
.lb{padding:20px}
.fg{margin-bottom:14px}.fg label{display:block;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#718096;margin-bottom:5px}
.fg input{width:100%;padding:9px 12px;border:1px solid #e2e8f0;border-radius:6px;font-size:13px}
.fg input:focus{outline:none;border-color:#c4a53e}
.btn{width:100%;padding:10px;background:#0d1b2a;color:#fff;border:none;border-radius:6px;font-size:13px;font-weight:700;cursor:pointer}
.footer{background:#0d1b2a;border-top:2px solid #c4a53e;padding:8px 24px;text-align:center;font-size:10.5px;color:rgba(255,255,255,.25)}
</style></head>
<body>
<div class="login-overlay" id="ov"><div class="login-box">
<div class="lh">🏢 &nbsp;PUL Employee Portal — Sign In</div>
<div class="lb">
<div class="fg"><label>Employee ID / Email</label><input type="text" placeholder="EMP-001 or user@prabalurja.in"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Network password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In with AD Credentials</button>
</div></div></div>
<div class="topbar"><span class="brand">PUL Employee Self-Service</span><span class="meta">HR & Administrative Portal | Prabal Urja Limited</span></div>
<div class="hero"><h1>Welcome to PUL ESS Portal</h1><p>Manage your HR requests, payslips, leaves, and administrative services</p></div>
<div class="main">
<div class="grid">
<div class="card" onclick="alert('Session expired. Please re-login.')"><div class="icon">📄</div><h3>Payslips & Tax</h3><p>Download payslips, Form-16, IT declarations</p></div>
<div class="card" onclick="alert('Session expired.')"><div class="icon">🗓</div><h3>Leave Management</h3><p>Apply for leave, view balance, approvals</p></div>
<div class="card" onclick="alert('Session expired.')"><div class="icon">🏥</div><h3>Medical Claims</h3><p>Submit and track reimbursement claims</p></div>
<div class="card" onclick="alert('Session expired.')"><div class="icon">📊</div><h3>Performance Review</h3><p>KPA submission and review tracking</p></div>
<div class="card" onclick="alert('Session expired.')"><div class="icon">🎓</div><h3>Training Requests</h3><p>Enrol in training programmes</p></div>
<div class="card" onclick="alert('Session expired.')"><div class="icon">🔐</div><h3>IT Access Requests</h3><p>Request system access and credentials</p></div>
</div></div>
<div class="footer">© 2024 Prabal Urja Limited. All Rights Reserved. | IT HR Systems | Classified: INTERNAL</div>
</body></html>
HTML
cat > "${TRAP_DIR}/ess/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m1-ess.log"
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
http.server.HTTPServer(("0.0.0.0",8090),H).serve_forever()
PYEOF
make_svc "itgw-m1-ess" "${TRAP_DIR}/ess/server.py" 8090

# ─── D3: IT Helpdesk / Ticketing — port 8181 ──────────────────────────────────
mkdir -p "${TRAP_DIR}/helpdesk"
cat > "${TRAP_DIR}/helpdesk/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL IT Helpdesk</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#f7f8fc;color:#2d3748;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#1a56db;padding:0 20px;height:56px;display:flex;align-items:center;justify-content:space-between;border-bottom:3px solid #c4a53e}
.hdr h1{color:#fff;font-size:15px;font-weight:700;display:flex;align-items:center;gap:8px}
.hdr .usr{color:rgba(255,255,255,.5);font-size:11px}
.nav{background:#1e40af;border-bottom:1px solid #1d4ed8;display:flex;padding:0 20px;gap:2px}
.nav a{color:rgba(255,255,255,.55);font-size:12.5px;padding:9px 14px;border-bottom:2px solid transparent;text-decoration:none}
.nav a.active{color:#fff;border-color:#c4a53e}
.main{flex:1;padding:20px;max-width:1100px;margin:0 auto;width:100%}
.stat-row{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px}
.stat{background:#fff;border:1px solid #e2e8f0;border-radius:7px;padding:14px;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.stat .n{font-size:24px;font-weight:800;color:#1a56db}.stat .l{font-size:11px;color:#718096;margin-top:3px;text-transform:uppercase;letter-spacing:.05em}
.stat.open .n{color:#d97706}.stat.crit .n{color:#dc2626}.stat.res .n{color:#059669}
.panel{background:#fff;border:1px solid #e2e8f0;border-radius:7px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.ph{background:#1e40af;color:#fff;padding:10px 14px;font-size:12.5px;font-weight:600;border-bottom:2px solid #c4a53e}
.table{width:100%;border-collapse:collapse;font-size:12.5px}
.table th{background:#f8fafc;padding:8px 14px;text-align:left;color:#718096;font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;border-bottom:1px solid #e2e8f0}
.table td{padding:10px 14px;border-bottom:1px solid #f7f8fc;color:#2d3748}
.table tr:hover td{background:#f0f7ff}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700}
.b-open{background:rgba(217,119,6,.12);color:#b45309}.b-pend{background:rgba(59,130,246,.12);color:#1d4ed8}
.b-res{background:rgba(5,150,105,.12);color:#047857}.b-crit{background:rgba(220,38,38,.12);color:#991b1b}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:360px;overflow:hidden}
.lh{background:#1a56db;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#fff;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:#718096;margin-bottom:4px}
.fg input{width:100%;padding:8px 10px;border:1px solid #e2e8f0;border-radius:5px;font-size:13px}
.fg input:focus{outline:none;border-color:#1a56db}
.btn{width:100%;padding:9px;background:#1a56db;color:#fff;border:none;border-radius:5px;font-size:13px;font-weight:700;cursor:pointer}
.footer{background:#1e3a8a;padding:8px 20px;text-align:center;font-size:10px;color:rgba(255,255,255,.25)}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">🎫 IT Helpdesk — Sign In</div>
<div class="lbody">
<div class="fg"><label>Employee ID</label><input type="text" placeholder="EMP-XXX or email"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Network password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>🎫 PUL IT Helpdesk</h1><div class="usr">NEXUS-IT Service Desk | Prabal Urja Limited</div></div>
<nav class="nav"><a href="#" class="active">Dashboard</a><a href="#">My Tickets</a><a href="#">New Ticket</a><a href="#">Knowledge Base</a><a href="#">Admin</a></nav>
<div class="main">
<div class="stat-row">
<div class="stat open"><div class="n">47</div><div class="l">Open Tickets</div></div>
<div class="stat crit"><div class="n">6</div><div class="l">Critical / P1</div></div>
<div class="stat"><div class="n">124</div><div class="l">In Progress</div></div>
<div class="stat res"><div class="n">891</div><div class="l">Resolved (30d)</div></div>
</div>
<div class="panel">
<div class="ph">Recent Tickets</div>
<table class="table">
<tr><th>Ticket ID</th><th>Subject</th><th>Raised By</th><th>Priority</th><th>Status</th><th>Assigned To</th></tr>
<tr><td style="font-family:monospace;font-size:11px">TKT-20241115-441</td><td>VPN connectivity failure — WFH users</td><td>priya.nair</td><td><span class="badge b-crit">P1</span></td><td><span class="badge b-open">OPEN</span></td><td>Arun Sharma</td></tr>
<tr><td style="font-family:monospace;font-size:11px">TKT-20241115-440</td><td>SSO login loop after password reset</td><td>deepa.iyer</td><td><span class="badge b-crit">P1</span></td><td><span class="badge b-open">OPEN</span></td><td>Unassigned</td></tr>
<tr><td style="font-family:monospace;font-size:11px">TKT-20241114-437</td><td>LDAP sync delay — AD connector timeout</td><td>arun.sharma</td><td><span class="badge b-pend">P2</span></td><td><span class="badge b-pend">IN PROGRESS</span></td><td>IT Infrastructure</td></tr>
<tr><td style="font-family:monospace;font-size:11px">TKT-20241114-432</td><td>Gitea repo access permission denied — svc-cicd</td><td>svc-deploy</td><td><span class="badge b-pend">P2</span></td><td><span class="badge b-res">RESOLVED</span></td><td>DevOps Team</td></tr>
<tr><td style="font-family:monospace;font-size:11px">TKT-20241113-421</td><td>Vault token expiry not notified — CI/CD pipeline</td><td>rajiv.menon</td><td><span class="badge b-open">P3</span></td><td><span class="badge b-res">RESOLVED</span></td><td>DevOps Team</td></tr>
</table></div></div>
<div class="footer">© 2024 Prabal Urja Limited | IT Helpdesk — NEXUS-IT Service Desk | Classification: INTERNAL</div>
</body></html>
HTML
cat > "${TRAP_DIR}/helpdesk/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m1-helpdesk.log"
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
http.server.HTTPServer(("0.0.0.0",8181),H).serve_forever()
PYEOF
make_svc "itgw-m1-helpdesk" "${TRAP_DIR}/helpdesk/server.py" 8181

# ─── D4: Document Management System — port 8282 ───────────────────────────────
mkdir -p "${TRAP_DIR}/dms"
cat > "${TRAP_DIR}/dms/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Document Management</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#f5f5f5;color:#333;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#0f3460;border-bottom:3px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#c4a53e;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.4);font-size:11px}
.toolbar{background:#fff;border-bottom:1px solid #ddd;padding:8px 20px;display:flex;align-items:center;gap:10px}
.tbtn{background:#0f3460;color:#fff;border:none;padding:7px 14px;border-radius:4px;font-size:12px;cursor:pointer}
.search{flex:1;max-width:360px;padding:7px 12px;border:1px solid #ddd;border-radius:4px;font-size:12px}
.main{flex:1;display:grid;grid-template-columns:220px 1fr;gap:0}
.sidebar{background:#fff;border-right:1px solid #ddd;padding:12px 0}
.sb-hdr{padding:8px 14px;font-size:10.5px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:#888}
.sb-item{padding:8px 14px;font-size:12.5px;cursor:pointer;display:flex;align-items:center;gap:8px;color:#444}
.sb-item:hover,.sb-item.active{background:#f0f7ff;color:#0f3460}
.content{padding:16px}
.file-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(130px,1fr));gap:12px}
.file-card{background:#fff;border:1px solid #ddd;border-radius:6px;padding:14px;text-align:center;cursor:pointer}
.file-card:hover{border-color:#c4a53e;box-shadow:0 2px 8px rgba(0,0,0,.08)}
.file-card .icon{font-size:28px;margin-bottom:8px}
.file-card .name{font-size:11px;color:#444;word-break:break-word}
.file-card .meta{font-size:10px;color:#aaa;margin-top:4px}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:360px;overflow:hidden}
.lh{background:#0f3460;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#c4a53e;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#888;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input{width:100%;padding:8px 10px;border:1px solid #ddd;border-radius:4px;font-size:13px}
.btn{width:100%;padding:9px;background:#0f3460;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer}
.footer{background:#0f3460;padding:8px 20px;text-align:center;font-size:10px;color:rgba(255,255,255,.25)}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">📁 PUL DMS — Authentication Required</div>
<div class="lbody">
<div class="fg"><label>Username</label><input type="text" placeholder="network username"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>📁 PUL Document Management System</h1><p>NEXUS-DMS v4.2 | Prabal Urja Limited</p></div>
<div class="toolbar">
<button class="tbtn">+ Upload</button><button class="tbtn">New Folder</button>
<input class="search" type="text" placeholder="Search documents...">
</div>
<div class="main">
<div class="sidebar">
<div class="sb-hdr">Libraries</div>
<div class="sb-item active">📂 IT Policies</div>
<div class="sb-item">📂 Grid Operations</div>
<div class="sb-item">📂 HR Documents</div>
<div class="sb-item">📂 Finance Records</div>
<div class="sb-item">📂 Vendor Contracts</div>
<div class="sb-item">📂 Security Audits</div>
<div class="sb-item">📂 Project Plans</div>
<div class="sb-item">🗑 Recycle Bin</div>
</div>
<div class="content">
<div class="file-grid">
<div class="file-card" onclick="alert('Access denied. Document is classified.')"><div class="icon">📑</div><div class="name">IT-Security-Policy-v3.pdf</div><div class="meta">2.4 MB · Nov 10</div></div>
<div class="file-card" onclick="alert('Access denied.')"><div class="icon">📊</div><div class="name">NEXUS-IT-Network-Topology-2024.xlsx</div><div class="meta">1.1 MB · Oct 28</div></div>
<div class="file-card" onclick="alert('Access denied.')"><div class="icon">📄</div><div class="name">Vault-Implementation-Guide.docx</div><div class="meta">840 KB · Sep 15</div></div>
<div class="file-card" onclick="alert('Access denied.')"><div class="icon">🔐</div><div class="name">ServiceAccount-Register-2024.xlsx</div><div class="meta">312 KB · Nov 01</div></div>
<div class="file-card" onclick="alert('Access denied.')"><div class="icon">📋</div><div class="name">Substation-SLD-NR-Zone.pdf</div><div class="meta">5.6 MB · Aug 22</div></div>
<div class="file-card" onclick="alert('Access denied.')"><div class="icon">📝</div><div class="name">CERT-In-Compliance-Checklist.docx</div><div class="meta">210 KB · Oct 05</div></div>
</div></div></div>
<div class="footer">© 2024 Prabal Urja Limited | Document Management System | Classification: RESTRICTED</div>
</body></html>
HTML
cat > "${TRAP_DIR}/dms/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m1-dms.log"
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
http.server.HTTPServer(("0.0.0.0",8282),H).serve_forever()
PYEOF
make_svc "itgw-m1-dms" "${TRAP_DIR}/dms/server.py" 8282

# ─── D5: Corporate Asset Inventory — port 8383 ────────────────────────────────
mkdir -p "${TRAP_DIR}/assets"
cat > "${TRAP_DIR}/assets/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Asset Inventory</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#f0f4f8;color:#1a202c;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#065f46;border-bottom:3px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#c4a53e;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.4);font-size:11px}
.main{flex:1;padding:20px;max-width:1100px;margin:0 auto;width:100%}
.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px}
.kpi{background:#fff;border:1px solid #d1fae5;border-radius:7px;padding:14px;border-left:3px solid #059669}
.kpi .n{font-size:24px;font-weight:800;color:#065f46}.kpi .l{font-size:11px;color:#6b7280;margin-top:3px;text-transform:uppercase;letter-spacing:.05em}
.panel{background:#fff;border:1px solid #e2e8f0;border-radius:7px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.ph{background:#065f46;color:#c4a53e;padding:10px 14px;font-size:12.5px;font-weight:700;border-bottom:2px solid #c4a53e}
.table{width:100%;border-collapse:collapse;font-size:12.5px}
.table th{background:#f0fdf4;padding:8px 14px;text-align:left;color:#6b7280;font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;border-bottom:1px solid #d1fae5}
.table td{padding:9px 14px;border-bottom:1px solid #f0f4f8;color:#1a202c}
.table tr:hover td{background:#f0fdf4}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700}
.b-active{background:rgba(5,150,105,.12);color:#047857}.b-dep{background:rgba(107,114,128,.12);color:#374151}
.b-maint{background:rgba(217,119,6,.12);color:#b45309}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:350px;overflow:hidden}
.lh{background:#065f46;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#c4a53e;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#6b7280;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input{width:100%;padding:8px 10px;border:1px solid #e2e8f0;border-radius:4px;font-size:13px}
.btn{width:100%;padding:9px;background:#065f46;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer}
.footer{background:#065f46;padding:8px 20px;text-align:center;font-size:10px;color:rgba(255,255,255,.25)}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">📦 Asset Inventory — Login Required</div>
<div class="lbody">
<div class="fg"><label>Username</label><input type="text" placeholder="IT Admin username"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>📦 PUL Corporate Asset Inventory</h1><p>CMDB / Asset Management | NEXUS-IT</p></div>
<div class="main">
<div class="kpis">
<div class="kpi"><div class="n">2,847</div><div class="l">Total Assets</div></div>
<div class="kpi"><div class="n">2,614</div><div class="l">Active</div></div>
<div class="kpi"><div class="n">183</div><div class="l">In Maintenance</div></div>
<div class="kpi"><div class="n">50</div><div class="l">Decommissioned</div></div>
</div>
<div class="panel">
<div class="ph">Recently Updated Assets</div>
<table class="table">
<tr><th>Asset Tag</th><th>Hostname</th><th>Type</th><th>IP</th><th>Owner</th><th>Status</th></tr>
<tr><td style="font-family:monospace;font-size:11px">PUL-SRV-0241</td><td>itgw-webportal</td><td>Server — Linux</td><td>203.x.x.x</td><td>IT Infrastructure</td><td><span class="badge b-active">ACTIVE</span></td></tr>
<tr><td style="font-family:monospace;font-size:11px">PUL-SRV-0242</td><td>itgw-mailrelay</td><td>Server — Linux</td><td>203.x.x.x</td><td>IT Infrastructure</td><td><span class="badge b-active">ACTIVE</span></td></tr>
<tr><td style="font-family:monospace;font-size:11px">PUL-SRV-0243</td><td>itgw-sso</td><td>Server — Linux</td><td>203.x.x.x</td><td>IT Operations</td><td><span class="badge b-active">ACTIVE</span></td></tr>
<tr><td style="font-family:monospace;font-size:11px">PUL-SRV-0244</td><td>itops-vault</td><td>Server — Linux</td><td>203.x.x.x</td><td>DevOps</td><td><span class="badge b-maint">MAINTENANCE</span></td></tr>
<tr><td style="font-family:monospace;font-size:11px">PUL-SW-0112</td><td>core-sw-north-01</td><td>Switch — Cisco Catalyst</td><td>193.x.x.x</td><td>Network Team</td><td><span class="badge b-active">ACTIVE</span></td></tr>
</table></div></div>
<div class="footer">© 2024 Prabal Urja Limited | IT Asset Management | Classification: INTERNAL</div>
</body></html>
HTML
cat > "${TRAP_DIR}/assets/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m1-assets.log"
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
http.server.HTTPServer(("0.0.0.0",8383),H).serve_forever()
PYEOF
make_svc "itgw-m1-assets" "${TRAP_DIR}/assets/server.py" 8383

# ─── D6: Visitor Management System — port 8484 ────────────────────────────────
mkdir -p "${TRAP_DIR}/visitor"
cat > "${TRAP_DIR}/visitor/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Visitor Management</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#fdf4e7;color:#1a202c;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:#92400e;border-bottom:3px solid #c4a53e;padding:0 20px;height:54px;display:flex;align-items:center;justify-content:space-between}
.hdr h1{color:#fef3c7;font-size:15px;font-weight:700}.hdr p{color:rgba(255,255,255,.4);font-size:11px}
.main{flex:1;padding:20px;max-width:900px;margin:0 auto;width:100%}
.section-hdr{font-size:13px;font-weight:700;color:#92400e;margin-bottom:12px;border-bottom:1px solid #f59e0b;padding-bottom:6px}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px}
.panel{background:#fff;border:1px solid #fde68a;border-radius:7px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.ph{background:#92400e;color:#fef3c7;padding:10px 14px;font-size:12.5px;font-weight:600;border-bottom:2px solid #c4a53e}
.pb{padding:14px}
.vrow{display:flex;align-items:center;gap:10px;padding:7px 0;border-bottom:1px solid #fef9c3;font-size:12.5px}
.vrow:last-child{border-bottom:none}
.vname{font-weight:600;color:#1a202c;width:160px;flex-shrink:0}.vmeta{color:#92400e;font-size:11px;flex:1}.vtime{font-family:monospace;font-size:11px;color:#d97706}
.badge-in{background:rgba(5,150,105,.12);color:#047857;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700}
.badge-out{background:rgba(107,114,128,.12);color:#374151;padding:2px 8px;border-radius:12px;font-size:10px;font-weight:700}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#92400e;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input,.fg select{width:100%;padding:8px 10px;border:1px solid #fde68a;border-radius:4px;font-size:13px;background:#fffbeb}
.btn{background:#92400e;color:#fff;border:none;padding:9px 20px;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer;width:100%}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:340px;overflow:hidden}
.lh{background:#92400e;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#fef3c7;font-size:13px;font-weight:700}
.lbody{padding:18px}
.footer{background:#92400e;padding:8px 20px;text-align:center;font-size:10px;color:rgba(255,255,255,.25)}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">🏢 Visitor Management — Security Desk Login</div>
<div class="lbody">
<div class="fg"><label>Security Officer ID</label><input type="text" placeholder="SEC-XXX"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Password"></div>
<button style="background:#92400e;color:#fff;border:none;padding:9px;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer;width:100%" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><h1>🏢 PUL Visitor Management System</h1><p>NEXUS-VMS | Security Operations | HQ New Delhi</p></div>
<div class="main">
<div class="grid2">
<div class="panel"><div class="ph">Today's Visitors (Active)</div><div class="pb">
<div class="vrow"><span class="vname">Rahul Kapoor</span><span class="vmeta">Siemens — Service Engineer</span><span class="badge-in">IN</span><span class="vtime">09:14</span></div>
<div class="vrow"><span class="vname">Ananya Krishnan</span><span class="vmeta">CERT-In — Audit Team</span><span class="badge-in">IN</span><span class="vtime">10:02</span></div>
<div class="vrow"><span class="vname">Mohan Lal</span><span class="vmeta">ABB Ltd — Vendor</span><span class="badge-in">IN</span><span class="vtime">11:30</span></div>
<div class="vrow"><span class="vname">Sunita Verma</span><span class="vmeta">MoP — Ministry Official</span><span class="badge-out">OUT</span><span class="vtime">13:45</span></div>
</div></div>
<div class="panel"><div class="ph">Register New Visitor</div><div class="pb">
<div class="fg"><label>Visitor Name</label><input type="text" placeholder="Full name"></div>
<div class="fg"><label>Organisation</label><input type="text" placeholder="Company / Agency"></div>
<div class="fg"><label>Purpose</label><select><option>Meeting</option><option>Vendor Service</option><option>Audit</option><option>Delivery</option></select></div>
<button class="btn" onclick="alert('Registration saved. Pass printed.')">Register & Print Pass</button>
</div></div>
</div></div>
<div class="footer">© 2024 Prabal Urja Limited | Security Operations — Visitor Management | Classification: INTERNAL</div>
</body></html>
HTML
cat > "${TRAP_DIR}/visitor/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m1-visitor.log"
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
http.server.HTTPServer(("0.0.0.0",8484),H).serve_forever()
PYEOF
make_svc "itgw-m1-visitor" "${TRAP_DIR}/visitor/server.py" 8484

# ─── D7: Corporate Intranet / Announcements — port 8585 ──────────────────────
mkdir -p "${TRAP_DIR}/intranet"
cat > "${TRAP_DIR}/intranet/index.html" << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>PUL Intranet</title>
<style>*{box-sizing:border-box;margin:0;padding:0}body{font-family:'Segoe UI',Arial,sans-serif;background:#f3f4f6;color:#111827;min-height:100vh;display:flex;flex-direction:column}
.hdr{background:linear-gradient(90deg,#0d1b2a,#1a3a5c);border-bottom:3px solid #c4a53e;padding:0 24px;height:60px;display:flex;align-items:center;justify-content:space-between}
.hdr .brand{display:flex;align-items:center;gap:12px}.hdr .logo{font-size:28px}.hdr h1{color:#c4a53e;font-size:16px;font-weight:800}
.hdr .meta{color:rgba(255,255,255,.35);font-size:11px}
.nav{background:#1a3a5c;border-bottom:1px solid #0d1b2a;display:flex;padding:0 24px;gap:2px}
.nav a{color:rgba(255,255,255,.5);font-size:12.5px;padding:9px 14px;border-bottom:2px solid transparent;text-decoration:none}
.nav a.active{color:#c4a53e;border-color:#c4a53e}
.main{flex:1;padding:20px 24px;display:grid;grid-template-columns:1fr 320px;gap:16px;max-width:1200px;margin:0 auto;width:100%}
.panel{background:#fff;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.ph{background:#0d1b2a;border-bottom:2px solid #c4a53e;padding:10px 14px;color:#c4a53e;font-size:12.5px;font-weight:700}
.pb{padding:14px}
.announce{padding:12px 0;border-bottom:1px solid #f3f4f6}
.announce:last-child{border-bottom:none}
.announce .title{font-size:13px;font-weight:600;color:#111827;margin-bottom:4px}
.announce .meta{font-size:11px;color:#9ca3af}.announce .body{font-size:12.5px;color:#4b5563;margin-top:6px;line-height:1.6}
.link-list{list-style:none}
.link-list li{padding:8px 0;border-bottom:1px solid #f3f4f6;display:flex;align-items:center;gap:8px;font-size:12.5px}
.link-list li:last-child{border-bottom:none}
.link-list a{color:#1a56db;text-decoration:none}.link-list a:hover{text-decoration:underline}
.login{position:fixed;inset:0;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;z-index:99}
.lb{background:#fff;border-radius:8px;width:360px;overflow:hidden}
.lh{background:#0d1b2a;border-bottom:2px solid #c4a53e;padding:14px 18px;color:#c4a53e;font-size:13px;font-weight:700}
.lbody{padding:18px}
.fg{margin-bottom:12px}.fg label{display:block;font-size:10.5px;font-weight:700;color:#6b7280;margin-bottom:4px;text-transform:uppercase;letter-spacing:.07em}
.fg input{width:100%;padding:8px 10px;border:1px solid #e5e7eb;border-radius:4px;font-size:13px}
.btn{width:100%;padding:9px;background:#0d1b2a;color:#fff;border:none;border-radius:4px;font-size:13px;font-weight:700;cursor:pointer}
.footer{background:#0d1b2a;padding:8px 24px;text-align:center;font-size:10px;color:rgba(255,255,255,.25)}
</style></head>
<body>
<div class="login" id="ov"><div class="lb">
<div class="lh">⚡ PUL Intranet — Sign In Required</div>
<div class="lbody">
<div class="fg"><label>Employee ID or Email</label><input type="text" placeholder="e.g. arun.sharma@prabalurja.in"></div>
<div class="fg"><label>Password</label><input type="password" placeholder="Network password"></div>
<button class="btn" onclick="document.getElementById('ov').style.display='none'">Sign In</button>
</div></div></div>
<div class="hdr"><div class="brand"><div class="logo">⚡</div><div><h1>PRABAL URJA LIMITED — Intranet</h1><div style="color:rgba(255,255,255,.3);font-size:10px">Internal Staff Portal</div></div></div><div class="meta">Friday, 15 Nov 2024</div></div>
<nav class="nav"><a href="#" class="active">Home</a><a href="#">Departments</a><a href="#">HR</a><a href="#">IT Services</a><a href="#">Policies</a><a href="#">Contact Directory</a></nav>
<div class="main">
<div>
<div class="panel" style="margin-bottom:14px"><div class="ph">📢 Announcements</div><div class="pb">
<div class="announce"><div class="title">CERT-In Annual IT Security Audit — 18–22 November 2024</div><div class="meta">IT Security | Posted by: rajiv.menon | 14 Nov 2024</div><div class="body">All IT staff are required to make systems available for audit review. Audit team will be on-site from 18 Nov. Kindly cooperate and ensure logs are available for the past 90 days.</div></div>
<div class="announce"><div class="title">NEXUS-IT Platform Maintenance Window — 16 Nov 02:00–06:00 IST</div><div class="meta">IT Infrastructure | Posted by: arun.sharma | 13 Nov 2024</div><div class="body">Planned maintenance for Vault migration and LDAP ACL updates. Some services may be intermittently unavailable. Grid ops will be unaffected — OT systems on separate network.</div></div>
<div class="announce"><div class="title">New VPN Policy — All Remote Access via Zscaler ZPA effective 1 Dec</div><div class="meta">IT Operations | Posted by: priya.nair | 10 Nov 2024</div><div class="body">Split-tunnel VPN is being discontinued. All remote access must route through Zscaler ZPA. Contact IT helpdesk for migration assistance.</div></div>
</div></div>
</div>
<div>
<div class="panel" style="margin-bottom:14px"><div class="ph">🔗 Quick Links</div><div class="pb">
<ul class="link-list">
<li>📋 <a href="#">PUL HR Policy Manual</a></li>
<li>🔐 <a href="#">IT Access Request Form</a></li>
<li>📞 <a href="#">IT Helpdesk — Ext 1100</a></li>
<li>📊 <a href="#">Grid Dashboard (Ops Only)</a></li>
<li>🏥 <a href="#">Medical Claim Portal</a></li>
<li>📁 <a href="#">Document Management</a></li>
</ul></div></div>
<div class="panel"><div class="ph">📅 Today at PUL HQ</div><div class="pb">
<ul class="link-list">
<li>🕙 10:00 — CERT-In Pre-Audit Call</li>
<li>🕐 13:00 — Grid Ops Review (Vidcon)</li>
<li>🕓 15:30 — NEXUS-IT Steering Comm.</li>
</ul></div></div>
</div>
</div>
<div class="footer">© 2024 Prabal Urja Limited | Internal Staff Portal | Classification: INTERNAL — Do not share externally</div>
</body></html>
HTML
cat > "${TRAP_DIR}/intranet/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server,logging,os
LOG="/var/log/pul-honeytrap/itgw-m1-intranet.log"
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
http.server.HTTPServer(("0.0.0.0",8585),H).serve_forever()
PYEOF
make_svc "itgw-m1-intranet" "${TRAP_DIR}/intranet/server.py" 8585

echo ""
echo "============================================================"
echo "  RNG-IT-01 | M1 itgw-webportal — Honeytraps Active"
echo "  D1: FTP banner           → port 2121 (socket)"
echo "  D2: Employee Self-Service→ port 8090"
echo "  D3: IT Helpdesk/Ticketing→ port 8181"
echo "  D4: Document Management  → port 8282"
echo "  D5: Asset Inventory      → port 8383"
echo "  D6: Visitor Management   → port 8484"
echo "  D7: Corporate Intranet   → port 8585"
echo "  Logs: ${LOG_DIR}/itgw-m1-*.log"
echo "============================================================"
