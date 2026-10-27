#!/usr/bin/env bash
# BLUE: ¿el firewall ya no se puede saltar hasta el SSH, sin romper la web?
# Se re-aplican las reglas del alumno y se simula el recorrido de la cadena
# INPUT para paquetes externos (eth0, estado NEW): es la pregunta real —
# ¿qué veredicto recibe un paquete que viene de fuera?
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 109 · BLUE (firewall) =="

# Re-aplica lo que el alumno dejó en /srv/fw/rules.sh.
sh /srv/fw/rules.sh 2>/tmp/fw.err || { echo "  rules.sh falló:"; cat /tmp/fw.err; }

# Servicios siguen vivos (no vale 'arreglar' matando los servicios).
for p in 80 22 8080; do
  ss -lnt 2>/dev/null | grep -q ":$p " || no "el servicio en :$p ya no escucha."
done
[ -s /opt/lab/.flags ] || no "faltan las banderas del escenario."

python3 - <<'PY'
import subprocess, sys
S = subprocess.run(["iptables","-S","INPUT"],capture_output=True,text=True).stdout
rules=[ln.split() for ln in S.splitlines() if ln.startswith("-A INPUT")]
policy="DROP"
for ln in S.splitlines():
    if ln.startswith("-P INPUT"): policy=ln.split()[2]

def tok(r,flag):
    return r[r.index(flag)+1] if flag in r else None

def dports_match(r,dport):
    # --dport N  o  -m multiport --dports a,b,c:d
    if "--dport" in r:
        return tok(r,"--dport")==str(dport)
    if "--dports" in r:
        for part in tok(r,"--dports").split(","):
            if ":" in part:
                lo,hi=part.split(":")
                if int(lo)<=dport<=int(hi): return True
            elif part==str(dport): return True
        return False
    return True  # sin condición de dport: aplica a cualquiera

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
 ("web publica (:80) sigue accesible", verdict(80,40000)=="ACCEPT"),
 ("SSH (:22) directo bloqueado", verdict(22,40000)!="ACCEPT"),
 ("SSH (:22) con puerto-origen 53 bloqueado", verdict(22,53)!="ACCEPT"),
 ("consola admin (:8080) directa bloqueada", verdict(8080,40000)!="ACCEPT"),
]
bad=0
for desc,good in checks:
    print(("  [OKPY] " if good else "  [NOPY] ")+desc)
    if not good: bad+=1
sys.exit(1 if bad else 0)
PY
rc=$?
# Traduce el resultado del simulador a los contadores ok/no.
if [ "$rc" -eq 0 ]; then ok "El firewall bloquea SSH y admin, y deja pasar la web."
else no "Todavía hay una vía para saltar el firewall (ver líneas NOPY)."; fi

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
