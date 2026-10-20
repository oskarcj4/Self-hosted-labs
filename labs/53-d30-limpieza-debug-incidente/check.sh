#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 53 (Día 30).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/home/analista/portal
IP=$(hostname -i 2>/dev/null | awk '{print $1}')

echo "== Lab 53 · Día 30 — comprobación =="

cfg=$(cd "$P" && $SUDO docker compose config --format json 2>/dev/null)
if [ -z "$cfg" ]; then
  no "docker compose config falla en $P (¿rompiste compose.yaml o .env?)."
else
  echo "$cfg" | python3 -c '
import json,sys
c=json.load(sys.stdin); sv=c["services"]
extra=[n for n in sv if n!="app"]
bypass=str(sv.get("app",{}).get("environment",{}).get("AUTH_BYPASS","")).lower()=="true"
print("EXTRA="+",".join(extra)); print("BYPASS="+("1" if bypass else "0"))' > /tmp/.tclab-53.$$
  extra=$(sed -n 's/^EXTRA=//p' /tmp/.tclab-53.$$); byp=$(sed -n 's/^BYPASS=//p' /tmp/.tclab-53.$$)
  rm -f /tmp/.tclab-53.$$
  [ -z "$extra" ] && ok "La configuración efectiva de Compose sólo tiene el servicio app." \
                  || no "La configuración efectiva sigue incluyendo: $extra"
  [ "$byp" = "0" ] && ok "La configuración efectiva ya no activa AUTH_BYPASS." \
                   || no "La configuración efectiva (con overrides) sigue activando AUTH_BYPASS."
fi

left=$(docker ps -a --format '{{.Names}} {{.Image}} {{.Ports}}' | grep -iE 'debug|7000' )
if [ -z "$left" ]; then ok "No queda ningún contenedor de depuración (ni parado)."
else no "Quedan contenedores de depuración: $left"; fi

if timeout 2 bash -c "exec 3<>/dev/tcp/$IP/7000" 2>/dev/null; then no "El puerto 7000 sigue abierto."
else ok "El puerto 7000 está cerrado."; fi

host_mounts=$(for c in $(docker ps -aq); do docker inspect -f '{{.Name}}{{range .Mounts}} {{.Source}}:{{.Destination}}{{end}}' "$c"; done | grep -E ' /:' )
if [ -z "$host_mounts" ]; then ok "Ningún contenedor monta la raíz del host."
else no "Hay contenedores con / del host montado: $host_mounts"; fi

a=$(docker ps -q --filter label=com.docker.compose.project=portal --filter label=com.docker.compose.service=app | head -1)
if [ -n "$a" ] && docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$a" | grep -qiE '^AUTH_BYPASS=true'; then
  no "El contenedor app en ejecución sigue con AUTH_BYPASS=true (¿lo recreaste?)."
fi

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://$IP:8000/admin")
home=$(curl -s --max-time 3 "http://$IP:8000/")
if [ "$code" = "401" ]; then ok "/admin vuelve a pedir autenticación (401)."
else no "/admin responde $code sin credenciales (debería ser 401)."; fi
if echo "$home" | grep -q "Portal de clientes"; then ok "El portal sigue funcionando."
else no "El portal no responde en :8000."; fi

key=$($SUDO sed -n 's/^ADMIN_KEY=//p' "$P/.env" 2>/dev/null)
if [ -n "$key" ] && [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 -H "X-Admin-Key: $key" "http://$IP:8000/admin")" = "200" ]; then
  ok "Con la clave correcta, /admin sigue accesible."
else
  no "Con la ADMIN_KEY de .env, /admin no funciona."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Restos del incidente eliminados. ¡Día 30 resuelto! 🏁 Reto de 30 días completado."; exit 0; } || exit 1
