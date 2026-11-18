#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
D=/home/analista/despliegue
LOG=/var/log/trafico/segundos.log

# errores/ok del tráfico entre dos epochs:  ventana DESDE HASTA -> "ok err"
ventana(){ awk -v a="$1" -v b="$2" '$1>=a && $1<=b {o+=$2; e+=$3} END {print o+0, e+0}' "$LOG"; }
version_de(){ curl -fs --max-time 2 "http://127.0.0.1:800$1/version" 2>/dev/null && echo || echo caida; }
estado_haproxy(){ echo "show stat" | socat stdio /run/haproxy/admin.sock 2>/dev/null | python3 -c '
import csv, sys
r = csv.reader(l for l in sys.stdin if l.strip())
cab = next(r); cab[0] = cab[0].lstrip("# ")
for f in r:
    d = dict(zip(cab, f))
    if d["pxname"] == "web" and d["svname"].startswith("web"):
        print(d["svname"], d["status"])'; }
desplegar(){ runuser -u analista -- bash -c "cd $D && timeout 300 ansible-playbook deploy.yml -e version=$1" > "/tmp/check-219-$1.log" 2>&1; }

echo "== Lab 219 · Rolling deploy con Ansible bajo tráfico — comprobación =="

if ! systemctl is-active -q trafico haproxy; then
  no "El tráfico real o HAProxy no están en marcha (systemctl status trafico haproxy)."
fi

# 1. Estructura del playbook y de HAProxy.
SERIAL=$(python3 -c '
import yaml, sys
try:
    plays = yaml.safe_load(open(sys.argv[1]))
    p = [x for x in plays if "web" in str(x.get("hosts", ""))][0]
    s = p.get("serial")
    print(s[0] if isinstance(s, list) else s)
except Exception as e:
    print("error")' "$D/deploy.yml")
if [ "$SERIAL" = 1 ]; then
  ok "El playbook despliega de una en una (serial: 1)."
else
  no "El play de web no tiene serial: 1 (tiene: ${SERIAL:-nada})."
fi
CFG=$(haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1 && cat /etc/haproxy/haproxy.cfg)
NCHK=$(printf '%s\n' "$CFG" | grep -cE '^\s*server\s+web[123]\s.*\bcheck\b')
if printf '%s\n' "$CFG" | grep -qE '^\s*option\s+httpchk.*/salud' && [ "$NCHK" = 3 ]; then
  ok "HAProxy comprueba /salud de las 3 instancias (option httpchk + check)."
else
  no "HAProxy no tiene 'option httpchk ... /salud' y 'check' en los 3 servers (o la config no valida)."
fi

# 2. Release rota: el despliegue debe pararse en la primera y los clientes no notar nada.
echo "  (desplegando v4-rc, que está rota, con tu playbook...)"
T0=$(date +%s); desplegar v4-rc; RC=$?; sleep 4; T1=$(date +%s)
read -r OK1 ERR1 < <(ventana "$T0" "$T1")
ROTAS=$(for i in 1 2 3; do readlink -f /srv/web/web$i/current; done | grep -c 'v4-rc')
if [ "$RC" -ne 0 ] && [ "$ROTAS" -le 1 ]; then
  ok "Con la release rota el playbook falla y se para ($ROTAS instancia tocada)."
else
  no "Con v4-rc el playbook terminó con código $RC y dejó $ROTAS instancias en v4-rc (debe fallar y tocar como mucho 1)."
fi
if [ "$ERR1" = 0 ] && [ "$OK1" -gt 0 ]; then
  ok "Durante el despliegue roto los clientes no vieron errores ($OK1 peticiones OK)."
else
  no "Durante el despliegue roto hubo $ERR1 peticiones con error (de $((OK1+ERR1))). Ver /var/log/trafico/errores.log"
fi

# 3. Release buena: todas actualizadas, de vuelta en HAProxy, sin errores.
echo "  (desplegando v3 con tu playbook...)"
T0=$(date +%s); desplegar v3; RC=$?; sleep 4; T1=$(date +%s)
read -r OK2 ERR2 < <(ventana "$T0" "$T1")
VS=$(for i in 1 2 3; do version_de $i; done | sort | uniq -c | xargs)
ST=$(estado_haproxy | xargs)
if [ "$RC" -eq 0 ] && [ "$VS" = "3 v3" ] && [ "$(estado_haproxy | grep -c ' UP$')" = 3 ]; then
  ok "v3 desplegada en las 3 instancias y las 3 están UP en HAProxy ($ST)."
else
  no "Tras desplegar v3: código $RC, versiones '$VS', HAProxy '$ST' (deben ser 3 v3 y 3 UP)."
fi
if [ "$ERR2" = 0 ] && [ "$OK2" -gt 0 ]; then
  ok "Durante el despliegue de v3 los clientes no vieron errores ($OK2 peticiones OK)."
else
  no "Durante el despliegue de v3 hubo $ERR2 peticiones con error (de $((OK2+ERR2)))."
fi

# 4. El tráfico no se ha "apagado" para hacer trampa.
read -r OK3 ERR3 < <(ventana $(( $(date +%s) - 10 )) "$(date +%s)")
if systemctl is-active -q trafico && [ "$OK3" -ge 300 ]; then
  ok "El tráfico real sigue a pleno ritmo ($OK3 peticiones OK en 10 s)."
else
  no "El generador de tráfico está parado o va muy lento ($OK3 OK en 10 s)."
fi

echo "  (salida de los despliegues: /tmp/check-219-v4-rc.log y /tmp/check-219-v3.log)"
echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Rolling deploy sin un solo error, y una release rota no pasa de la primera instancia."; exit 0; } || exit 1
