#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
source /opt/lab/forja.sh
BARE=$GITEA_WORK/data/gitea-repositories/analista/reservas.git
HEAD=$(git --git-dir "$BARE" rev-parse main 2>/dev/null)
W=/var/www/reservas

echo "== Lab 216 · Pipeline full stack PHP — comprobación =="

EST=$(forja_estado_sha reservas "$HEAD")
case $EST in corriendo|esperando|bloqueado)
  echo "  (el pipeline de ${HEAD:0:8} sigue en marcha: esperando hasta 3 min...)"
  EST=$(forja_espera_sha reservas "$HEAD" 180);;
esac
LOG=$(forja_log_sha reservas "$HEAD")
if [ "$EST" = ok ]; then
  ok "El pipeline del último commit de main (${HEAD:0:8}) está en verde."
else
  no "El pipeline de ${HEAD:0:8} está '$EST' (ci-estado, ci-log)."
fi

N=$(printf '%s\n' "$LOG" | sed -n 's/.*OK (\([0-9]*\) tests.*/\1/p' | tail -1)
WF=$(python3 /opt/lab/wf.py "$BARE" publicar-reservas phpunit 2>/dev/null)
j(){ python3 -c 'import json,sys;print(json.loads(sys.argv[1] or "{}").get(sys.argv[2]))' "$WF" "$1"; }
if [ "${N:-0}" -ge 5 ]; then
  ok "PHPUnit corre en el pipeline y pasa ($N tests)."
else
  no "El log del pipeline no tiene PHPUnit en verde ('OK (N tests')."
fi
if [ "$(j coe)" = False ] && [ "$(j orden)" = True ]; then
  ok "Sólo se publica si pasan los tests."
else
  no "Se publica sin pasar los tests (o con continue-on-error)."
fi
if [ "$(j rama)" = True ]; then
  ok "Sólo se despliega desde main."
else
  no "El workflow despliega desde cualquier rama."
fi
if [ -n "$HEAD" ] && ! git --git-dir "$BARE" cat-file -e "main:.env" 2>/dev/null; then
  ok "El .env ya no está en el repo."
else
  no "El .env con secretos sigue versionado en main."
fi

# Estructura de despliegue atómico.
CUR=$(readlink "$W/current" 2>/dev/null)
NREL=$(find "$W/releases" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
if [ -L "$W/current" ] && [ "$(readlink -f "$W/current")" = "$W/releases/$HEAD" ] \
   && nginx -T 2>/dev/null | grep -qE "root +$W/current/public"; then
  ok "Despliegue atómico: current -> releases/${HEAD:0:8}, y nginx sirve current/public."
else
  no "$W/current no es un enlace a releases/<sha de main> (es '${CUR:-nada}'), o nginx no sirve current/public."
fi
if [ "$NREL" -ge 1 ] && [ "$NREL" -le 5 ]; then
  ok "Se guardan como mucho 5 releases ($NREL)."
else
  no "Hay $NREL releases en $W/releases (deben quedar entre 1 y 5)."
fi
R="$W/releases/$HEAD"
if [ -d "$R/vendor" ] && [ ! -e "$R/.git" ] && [ ! -d "$R/vendor/phpunit" ] && [ ! -d "$R/vendor/phpstan" ]; then
  ok "La release no lleva .git ni dependencias de desarrollo (composer --no-dev)."
else
  no "La release de producción lleva .git o vendor/phpunit (o no tiene vendor)."
fi

# shared: .env y datos fuera de las releases; contraseña rotada.
ENVF=$(readlink -f "$R/.env" 2>/dev/null)
DBP=$(sed -n 's/^DB_PATH *= *//p' "$W/shared/.env" 2>/dev/null)
PASS=$(sed -n 's/^SMTP_PASS *= *//p' "$W/shared/.env" 2>/dev/null)
if [ "$ENVF" = "$W/shared/.env" ] && [[ "$DBP" == "$W/shared/"* ]]; then
  ok "La release usa shared/.env, y la base vive en shared/ ($DBP)."
else
  no "La release no enlaza shared/.env, o DB_PATH ('${DBP:-?}') no está en $W/shared/."
fi
if [ -n "$PASS" ] && [ "$PASS" != 'Smtp-Reservas-2026!' ]; then
  ok "La contraseña SMTP que estuvo en git se ha rotado."
else
  no "SMTP_PASS en shared/.env sigue siendo la que se filtró en git (rótala)."
fi
LISTA=$(curl -fs http://127.0.0.1:8080/api/reservas 2>/dev/null)
if printf '%s' "$LISTA" | grep -q comite-seguridad && printf '%s' "$LISTA" | grep -q direccion; then
  ok "Las reservas de producción siguen ahí."
else
  no "Producción ha perdido las reservas reales (hay copia en /var/backups/)."
fi

# Producción corre main y el bug está arreglado.
V=$(curl -fs http://127.0.0.1:8080/api/version 2>/dev/null)
if printf '%s' "$V" | grep -q "$HEAD"; then
  ok "Producción corre el último commit de main (${HEAD:0:8})."
else
  no "Producción no corre ${HEAD:0:8} (/api/version: ${V:-sin respuesta}; ¿opcache sin recargar?)."
fi
SALA="chk-$RANDOM"
A=$(curl -s -o /dev/null -w '%{http_code}' -X POST -d "{\"sala\":\"$SALA\",\"dia\":\"2030-01-01\",\"desde\":10,\"hasta\":11,\"quien\":\"check\"}" http://127.0.0.1:8080/api/reservas)
B=$(curl -s -o /dev/null -w '%{http_code}' -X POST -d "{\"sala\":\"$SALA\",\"dia\":\"2030-01-01\",\"desde\":11,\"hasta\":12,\"quien\":\"check\"}" http://127.0.0.1:8080/api/reservas)
LIMPIA=${DBP:-$(sed -n 's/^DB_PATH *= *//p' "$W/current/.env" "$W/.env" 2>/dev/null | head -1)}
[ -n "$LIMPIA" ] && [ -f "$LIMPIA" ] && php -r '$d=new PDO("sqlite:".$argv[1]);$d->prepare("DELETE FROM reservas WHERE sala=?")->execute([$argv[2]]);' "$LIMPIA" "$SALA" 2>/dev/null
if [ "$A" = 201 ] && [ "$B" = 201 ]; then
  ok "Se puede reservar una sala justo cuando acaba otra reserva."
else
  no "Reservas consecutivas (10-11 y 11-12): respuestas $A y $B (deben ser 201 y 201)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Releases atómicas, datos a salvo y secretos fuera de git."; exit 0; } || exit 1
