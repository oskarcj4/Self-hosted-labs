#!/usr/bin/env bash
# BLUE: ¿el panel ya está parcheado y el CVE cerrado, sin romper el firewall
# ni apagar el servicio? El firewall debe seguir correcto; el panel, servido y
# en versión >= 1.930; y el exploit no debe conseguir ejecución de código.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 110 · BLUE (panel sin parchear) =="

# Re-aplica el firewall (es correcto; solo lo reponemos por si acaso).
sh /srv/fw/rules.sh 2>/tmp/fw.err || { echo "  rules.sh falló:"; cat /tmp/fw.err; }

# Servicios siguen vivos (no vale 'arreglar' apagando el panel).
for p in 80 10000 22 8080; do
  ss -lnt 2>/dev/null | grep -q ":$p " || no "el servicio en :$p ya no escucha."
done
[ -s /opt/lab/.flags ] || no "faltan las banderas del escenario."

# --- 1) El firewall sigue siendo correcto -----------------------------------
python3 - <<'PY'
import subprocess, sys
S = subprocess.run(["iptables","-S","INPUT"],capture_output=True,text=True).stdout
rules=[ln.split() for ln in S.splitlines() if ln.startswith("-A INPUT")]
policy="DROP"
for ln in S.splitlines():
    if ln.startswith("-P INPUT"): policy=ln.split()[2]

def tok(r,flag): return r[r.index(flag)+1] if flag in r else None
def dports_match(r,dport):
    if "--dport" in r: return tok(r,"--dport")==str(dport)
    if "--dports" in r:
        for part in tok(r,"--dports").split(","):
            if ":" in part:
                lo,hi=part.split(":")
                if int(lo)<=dport<=int(hi): return True
            elif part==str(dport): return True
        return False
    return True
def matches(r,dport,sport,iface,state):
    if "-i" in r and tok(r,"-i")!=iface: return False
    if "-p" in r and tok(r,"-p") not in ("tcp",): return False
    if ("--state" in r or "--ctstate" in r):
        st=tok(r,"--state") or tok(r,"--ctstate")
        if state not in st.split(","): return False
    if "--sport" in r and tok(r,"--sport")!=str(sport): return False
    if not dports_match(r,dport): return False
    return True
def verdict(dport,sport,iface="eth0",state="NEW"):
    for r in rules:
        if "-j" not in r: continue
        if matches(r,dport,sport,iface,state):
            t=tok(r,"-j")
            if t in ("ACCEPT","DROP","REJECT"): return t
    return policy

checks=[
 ("politica INPUT es DROP (lista blanca)", policy=="DROP"),
 ("web publica (:80) accesible", verdict(80,40000)=="ACCEPT"),
 ("panel de gestion (:10000) accesible", verdict(10000,40000)=="ACCEPT"),
 ("SSH interno (:22) bloqueado desde fuera", verdict(22,40000)!="ACCEPT"),
 ("consola admin (:8080) bloqueada desde fuera", verdict(8080,40000)!="ACCEPT"),
]
bad=0
for desc,good in checks:
    print(("  [OKPY] " if good else "  [NOPY] ")+desc)
    if not good: bad+=1
sys.exit(1 if bad else 0)
PY
[ "$?" -eq 0 ] && ok "El firewall sigue correcto (no se rompió)." \
               || no "Se alteró el firewall: ya no es correcto (ver NOPY)."

# --- 2) Webmin parcheado (>= 1.930) -----------------------------------------
VER=$(cat /usr/share/webmin/version 2>/dev/null)
if [ -n "$VER" ] && dpkg --compare-versions "$VER" ge 1.930; then
  ok "Webmin actualizado: versión $VER (>= 1.930)."
else
  no "Webmin sigue sin parchear: versión ${VER:-desconocida} (< 1.930)."
fi

# --- 3) El exploit del CVE ya no ejecuta código -----------------------------
# Se lanza la misma petición de CVE-2019-15107 contra el panel local y se
# comprueba que NO aparece salida de comando (uid= / marcador).
MARK="TCLAB_RCE_PROBE_$$"
OUT=$(curl -sk --max-time 10 "https://127.0.0.1:10000/password_change.cgi" \
  -H "Referer: https://127.0.0.1:10000/session_login.cgi" \
  -H "Cookie: redirect=1; testing=1; sid=x; sessiontest=1" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "user=rootxx&pam=&expired=2&old=test|id;echo ${MARK};&new1=t&new2=t" 2>/dev/null)
if echo "$OUT" | grep -qE "uid=|$MARK"; then
  no "El exploit SIGUE ejecutando código en el panel (RCE abierto)."
else
  ok "El exploit ya no ejecuta código: RCE cerrado."
fi

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
