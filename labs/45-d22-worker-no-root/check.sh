#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 45 (Día 22). Deja un trabajo nuevo y espera a que se procese.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/home/analista/media
c=$(docker ps -q --filter label=com.docker.compose.project=media --filter label=com.docker.compose.service=thumbnailer | head -1)

echo "== Lab 45 · Día 22 — comprobación =="

if [ -z "$c" ]; then
  no "El thumbnailer no está corriendo."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi

u=$(docker inspect -f '{{.Config.User}}' "$c")
uid=$(docker exec "$c" id -u 2>/dev/null)
if [ -n "$u" ] && [ "$uid" != "0" ] && ! echo "$u" | grep -qE '^(root|0)(:|$)'; then
  ok "El worker corre sin privilegios (user: $u, uid $uid)."
else
  no "El worker sigue corriendo como root (user: '${u}', uid ${uid:-?})."
fi

if [ "$(docker inspect -f '{{.Config.User}}' media/thumbnailer:1.0 2>/dev/null)" != "" ] \
   || (cd "$P" && docker compose config --format json 2>/dev/null) | python3 -c '
import json,sys; sys.exit(0 if json.load(sys.stdin)["services"]["thumbnailer"].get("user") else 1)'; then
  ok "El usuario está fijado en la imagen o en compose.yaml (sobrevive a recrear)."
else
  no "El usuario no está fijado ni en la imagen ni en compose.yaml."
fi

n="tclab-$$.jpg"
echo "prueba" | $SUDO tee "$P/jobs/in/$n" >/dev/null
for _ in $(seq 1 10); do $SUDO test -e "$P/jobs/out/$n.thumb" && break; sleep 1; done
if $SUDO test -e "$P/jobs/out/$n.thumb" && $SUDO test -e "$P/jobs/done/$n" && ! $SUDO test -e "$P/jobs/in/$n"; then
  ok "Un trabajo nuevo se procesa de principio a fin ($($SUDO cat "$P/jobs/out/$n.thumb"))."
else
  no "El trabajo nuevo no se procesó (revisa: docker compose logs thumbnailer)."
fi
$SUDO rm -f "$P/jobs/in/$n" "$P/jobs/out/$n.thumb" "$P/jobs/done/$n"

if [ -z "$($SUDO find "$P/jobs" -perm -0002 2>/dev/null)" ]; then
  ok "Ninguna carpeta de trabajos es escribible por todos."
else
  no "Hay carpetas de trabajos escribibles por todos (777 no es la solución)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Worker sin root y funcionando. ¡Día 22 resuelto!"; exit 0; } || exit 1
