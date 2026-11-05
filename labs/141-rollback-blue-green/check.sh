#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 141.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
SOCK=/run/haproxy/admin.sock
CFG=/etc/haproxy/haproxy.cfg
api(){ echo "$1" | $SUDO socat stdio "$SOCK" 2>/dev/null; }
# srv_op_state (campo 6: 0 parado, 2 en marcha) y srv_admin_state (campo 7: bit 1 = maint)
estado(){ api "show servers state shop" | awk -v s="$1" '$4==s {print $6, $7}'; }

echo "== Lab 141 · Rollback en menos de 2 minutos — comprobación =="
grep -qE '^version_mala=1\.5\.0\s*$' $H/incidente.txt 2>/dev/null && grep -qE '^version_buena=1\.4\.0\s*$' $H/incidente.txt \
  && ok "incidente.txt: versión mala 1.5.0 y buena 1.4.0." || no "incidente.txt: falta version_mala=/version_buena= correctas."
$SUDO haproxy -c -f $CFG >/dev/null 2>&1 && ok "haproxy -c: configuración válida." || no "haproxy -c falla."
[ "$($SUDO systemctl show -p MainPID --value haproxy)" = "$($SUDO cat /opt/lab/.haproxy-pid)" ] \
  && ok "HAProxy no se reinició (mismo proceso maestro; reload sí vale)." || no "HAProxy se reinició: el rollback debe hacerse sin restart."
$SUDO grep -qE '^\s*stats socket \S+ .*level admin' $CFG && ok "Socket de la runtime API con level admin." || no "El stats socket no tiene level admin."
$SUDO grep -qE '^\s*option httpchk (GET )?/health' $CFG && ok "El health check mira /health." || no "El health check sigue sin mirar /health."

# El health check, por sí solo, debe sacar a green: lo ponemos 'ready' y esperamos.
api "set server shop/green state ready" >/dev/null; sleep 6
read -r op _ <<<"$(estado green)"
[ "${op:-9}" = 0 ] && ok "Con el health check nuevo, green (roto) queda DOWN solo." || no "green sigue UP para el health check (op_state=${op:-?})."

if [ -f $H/rollback.sh ]; then
  t0=$(date +%s)
  timeout 120 bash $H/rollback.sh >/dev/null 2>&1; rc=$?
  t=$(( $(date +%s) - t0 ))
  read -r _ adm <<<"$(estado green)"
  [ "$rc" = 0 ] && [ "$t" -lt 120 ] && ok "rollback.sh terminó bien en ${t}s." || no "rollback.sh falló o tardó demasiado (rc=$rc, ${t}s)."
  [ $(( ${adm:-0} & 1 )) = 1 ] && ok "rollback.sh deja green en mantenimiento (runtime API)." || no "Tras rollback.sh, green no está en maint."
  timeout 120 bash $H/rollback.sh >/dev/null 2>&1 && ok "rollback.sh se puede ejecutar dos veces." || no "rollback.sh falla la segunda vez (no es idempotente)."
else
  no "No existe ~/rollback.sh."
fi

okc=0; for _ in $(seq 1 40); do
  r=$(curl -s -o /dev/null -D - --max-time 3 http://127.0.0.1/api/checkout)
  echo "$r" | head -1 | grep -q ' 200' && echo "$r" | grep -qi '^X-App-Version: 1\.4\.0' && okc=$((okc+1))
done
[ "$okc" = 40 ] && ok "40/40 checkouts con 200 servidos por blue 1.4.0." || no "Sólo $okc/40 checkouts OK desde blue."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Rollback hecho, health check real y runbook probado."; exit 0; } || exit 1
