#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 44 (Día 21).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/home/analista/edge
c=$(docker ps -q --filter label=com.docker.compose.project=edge --filter label=com.docker.compose.service=gateway | head -1)

echo "== Lab 44 · Día 21 — comprobación =="

if [ -z "$c" ]; then
  no "El gateway no está corriendo (docker compose ps / docker compose logs)."
else
  rw=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/etc/gateway"}}{{.RW}}{{end}}{{end}}' "$c")
  if [ "$rw" = "false" ]; then ok "/etc/gateway está montado en sólo lectura."
  elif [ -z "$rw" ]; then no "La configuración ya no se monta en /etc/gateway."
  else no "/etc/gateway sigue montado en lectura/escritura."; fi

  if docker exec "$c" sh -c 'echo x > /etc/gateway/tclab-probe' 2>/dev/null; then
    docker exec "$c" rm -f /etc/gateway/tclab-probe
    no "Desde dentro del contenedor todavía se puede escribir en /etc/gateway."
  else
    ok "Desde dentro del contenedor no se puede modificar la configuración."
  fi

  h=$(curl -s --max-time 3 http://127.0.0.1:8080/health)
  if echo "$h" | grep -q "gateway ok: 3 rutas"; then ok "El gateway está sano ($h)."
  else no "El gateway no responde bien en /health: ${h:-sin respuesta}"; fi
fi

if [ "$(sha256sum "$P/config/routes.conf" 2>/dev/null | cut -d' ' -f1)" = "$($SUDO cat /root/.tclab-routes.sha)" ]; then
  ok "routes.conf sigue intacto."
else
  no "routes.conf ha cambiado o no existe."
fi

if (cd "$P" && docker compose config --format json 2>/dev/null) | python3 -c '
import json,sys
v=[x for x in json.load(sys.stdin)["services"]["gateway"].get("volumes",[]) if x.get("target")=="/etc/gateway"]
sys.exit(0 if v and v[0].get("read_only") else 1)'; then
  ok "compose.yaml declara la configuración como sólo lectura."
else
  no "compose.yaml no declara /etc/gateway como sólo lectura."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Configuración inmutable para el contenedor. ¡Día 21 resuelto!"; exit 0; } || exit 1
