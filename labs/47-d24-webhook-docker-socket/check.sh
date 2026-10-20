#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 47 (Día 24).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/home/analista/deployhook
c=$(docker ps -q --filter label=com.docker.compose.project=deployhook --filter label=com.docker.compose.service=webhook | head -1)

echo "== Lab 47 · Día 24 — comprobación =="

[ -n "$c" ] || { no "El webhook no está corriendo."; echo "Resultado: $pass superados, $fail pendientes."; exit 1; }

m=$(docker inspect -f '{{range .Mounts}}{{.Source}} {{.Destination}} {{end}}' "$c")
if echo "$m" | grep -q 'docker.sock'; then no "El contenedor sigue montando el socket de Docker."
else ok "El contenedor ya no monta el socket de Docker."; fi

if docker exec "$c" sh -c 'ls /var/run/docker.sock /run/docker.sock' >/dev/null 2>&1; then
  no "Dentro del contenedor sigue existiendo un docker.sock."
else
  ok "Dentro del contenedor no hay ningún docker.sock."
fi

dh=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" | grep -E '^DOCKER_HOST=' )
if [ -z "$dh" ]; then ok "Tampoco se le da acceso al daemon por TCP (DOCKER_HOST)."
else no "El contenedor tiene $dh: sigue hablando con el daemon."; fi

if curl -s --max-time 3 http://127.0.0.1:8090/debug/containers | grep -q '^/'; then
  no "/debug/containers todavía lista los contenedores del host."
else
  ok "/debug/containers ya no puede consultar Docker."
fi

tag="tclab-$$-$(date +%s)"
r=$(curl -s --max-time 3 -X POST -d "{\"repo\":\"$tag\"}" http://127.0.0.1:8090/hook)
sleep 1
if echo "$r" | grep -q registrado && $SUDO grep -q "$tag" "$P/events/events.log" 2>/dev/null; then
  ok "POST /hook sigue registrando eventos en events/events.log."
else
  no "Los webhooks ya no se registran: ${r:-sin respuesta}"
fi

if (cd "$P" && docker compose config 2>/dev/null) | grep -q 'docker.sock'; then
  no "compose.yaml sigue montando docker.sock."
else
  ok "compose.yaml ya no monta docker.sock."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Webhook sin las llaves del host. ¡Día 24 resuelto!"; exit 0; } || exit 1
