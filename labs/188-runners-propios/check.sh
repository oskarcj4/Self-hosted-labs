#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
TOKEN=$(cat /opt/lab/.token)
BASE=$(sed -n 's/^ *base *= *//p' /etc/runner/runner.ini 2>/dev/null | tail -1); BASE=${BASE:-/srv/ci}
U=$(systemctl show runner -p User --value)

echo "== Lab 188 · Runner propio — comprobación =="

if ! systemctl is-active -q runner; then
  no "runner.service no está activo (journalctl -u runner)."
  echo "Resultado: $pass superados, $((fail)) pendientes."; exit 1
fi

# job ID ETIQUETAS SCRIPT [espera]: encola y espera el resultado en $J (JSON).
job(){
  local id="chk$1-$RANDOM" t=${4:-20}
  python3 -c 'import json,sys;print(json.dumps({"id":sys.argv[1],"etiquetas":sys.argv[2].split(","),"script":sys.argv[3]}))' \
    "$id" "$2" "$3" > "$BASE/cola/.$id" && chown --reference="$BASE/cola" "$BASE/cola/.$id" 2>/dev/null
  mv "$BASE/cola/.$id" "$BASE/cola/$id.json"
  J=""; for _ in $(seq 1 $((t*2))); do
    [ -e "$BASE/resultados/$id.json" ] && { J=$(cat "$BASE/resultados/$id.json"); break; }; sleep 0.5
  done
  JID=$id
}
campo(){ python3 -c 'import json,sys;d=json.loads(sys.argv[1] or "{}");print(d.get(sys.argv[2],""))' "$J" "$1"; }

job 1 linux 'echo hola-runner'
if [ "$(campo estado)" = ok ] && campo salida | grep -q hola-runner; then
  ok "El runner sigue funcionando (job de prueba en verde)."
else
  no "Un job sencillo no termina bien: '$(campo estado)' (¿permisos de $BASE para el nuevo usuario?)."
fi

job 2 linux 'id -u; id -un; cat /etc/shadow >/dev/null 2>&1 && echo LEE-SHADOW; env'
S=$(campo salida)
UID_JOB=$(echo "$S" | sed -n 1p); USR_JOB=$(echo "$S" | sed -n 2p)
if [ -n "$UID_JOB" ] && [ "$UID_JOB" != 0 ] && [ "$USR_JOB" = ci-runner ] && ! echo "$S" | grep -q LEE-SHADOW; then
  ok "Los jobs corren como ci-runner (uid $UID_JOB), no como root."
else
  no "Los jobs corren como '${USR_JOB:-?}' (uid ${UID_JOB:-?}); debe ser ci-runner."
fi
if [ -n "$S" ] && ! echo "$S" | grep -q "$TOKEN"; then
  ok "El job no ve el token del registro."
else
  no "El token del registro llega al entorno del job."
fi

job 3 linux 'echo robado > secreto.txt; pwd'
WS3=$(campo salida | tail -1)
job 4 linux 'ls -A; pwd'
S4=$(campo salida)
if [ -n "$S4" ] && ! echo "$S4" | grep -q secreto.txt && [ "$(echo "$S4" | tail -1)" != "$WS3" ] && [ ! -e "$WS3/secreto.txt" ]; then
  ok "Cada job tiene su propio espacio de trabajo, y se borra al terminar."
else
  no "El espacio de trabajo se comparte o no se borra (el siguiente job ve secreto.txt, o $WS3 sigue ahí)."
fi

job 5 linux "cat /home/analista/notas.txt 2>&1 | head -1; echo x > /tmp/fuga-\$CI_JOB_ID; echo x > /var/tmp/fuga-\$CI_JOB_ID"
if ! campo salida | grep -q 'Oficina-2026'; then
  ok "El job no puede leer /home."
else
  no "El job lee /home/analista/notas.txt."
fi
if [ ! -e "/tmp/fuga-$JID" ] && [ ! -e "/var/tmp/fuga-$JID" ]; then
  ok "Lo que el job deja en /tmp no llega al /tmp del servidor."
else
  no "El job escribe en el /tmp o /var/tmp del servidor."
fi
rm -f "/tmp/fuga-$JID" "/var/tmp/fuga-$JID"

job 6 linux 'sleep 600 & sleep 600; echo no-deberia' 90
if [ "$(campo estado)" = timeout ] && python3 -c "import json,sys;sys.exit(0 if json.loads(sys.argv[1])['segundos']<=65 else 1)" "$J" 2>/dev/null; then
  sleep 1
  if pgrep -u "${U:-ci-runner}" -f 'sleep 600' >/dev/null || pgrep -f '^sleep 600' >/dev/null; then
    no "El job acaba en timeout, pero sus procesos siguen vivos."
  else
    ok "Un job colgado acaba en timeout (≤ 60 s) y sus procesos mueren."
  fi
else
  no "Un 'sleep 600' no termina en timeout en ≤ 60 s (estado '$(campo estado)')."
fi
pkill -f '^sleep 600' 2>/dev/null

job 7 gpu 'echo no-deberia-correr'
E7=$(campo estado)
job 8 linux,x64 'echo vale'
E8=$(campo estado)
if [ "$E7" = rechazado ] && [ "$E8" = ok ]; then
  ok "Sólo acepta etiquetas linux y x64."
else
  no "Etiquetas: un job 'gpu' queda '$E7' (debe rechazarse) y uno 'linux,x64' queda '$E8'."
fi

P=$(systemctl show runner -p NoNewPrivileges -p PrivateTmp -p ProtectSystem -p ProtectHome -p MemoryMax)
v(){ echo "$P" | sed -n "s/^$1=//p"; }
FALTA=""
[ "$(v NoNewPrivileges)" = yes ] || FALTA="$FALTA NoNewPrivileges"
[ "$(v PrivateTmp)" = yes ] || FALTA="$FALTA PrivateTmp"
case "$(v ProtectSystem)" in full|strict) ;; *) FALTA="$FALTA ProtectSystem";; esac
case "$(v ProtectHome)" in yes|read-only|tmpfs) ;; *) FALTA="$FALTA ProtectHome";; esac
[ "$(v MemoryMax)" != infinity ] || FALTA="$FALTA MemoryMax"
[ -z "$FALTA" ] && ok "runner.service con sandbox: NoNewPrivileges, PrivateTmp, ProtectSystem, ProtectHome y MemoryMax." \
               || no "Falta en runner.service:$FALTA."
if grep -rqs "$TOKEN" /etc/systemd/system/runner.service /etc/systemd/system/runner.service.d/; then
  no "El token sigue en la unidad, legible por todos (muévelo a un fichero 0600 con EnvironmentFile o LoadCredential)."
else
  ok "El token ya no está en la unidad."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Un PR malicioso ya no se lleva nada del runner."; exit 0; } || exit 1
