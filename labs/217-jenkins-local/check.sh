#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 217 · Jenkins local bien montado — comprobación =="

ENVS=$(systemctl show jenkins -p Environment --value 2>/dev/null)
J=$(printf '%s\n' $ENVS | sed -n 's/^JENKINS_HOME=//p'); J=${J:-/var/lib/jenkins}
CASC=$(printf '%s\n' $ENVS | sed -n 's/^CASC_JENKINS_CONFIG=//p')
U=$(systemctl show jenkins -p User --value 2>/dev/null)

# 1. Usuario propio.
if systemctl is-active -q jenkins && [ -n "$U" ] && [ "$U" != root ] && [ "$(stat -c %U "$J")" = "$U" ]; then
  ok "Jenkins corre como '$U' (no root) y es dueño de $J."
else
  no "Jenkins no está activo, corre como root, o $J no es de su usuario (User='${U:-root}')."
fi

# 2. Seguridad: nada sin login.
A=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/json)
S=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/manage/)
if [ "$A" = 403 ] && [ "$S" = 403 ] && grep -q '<useSecurity>true' "$J/config.xml" 2>/dev/null; then
  ok "Sin login no se ve ni se ejecuta nada (403)."
else
  no "Un anónimo aún entra (api/json: $A, manage: $S; deben ser 403)."
fi

# 3. Configuration as Code, sin secretos dentro.
if [ -n "$CASC" ] && [ -f "$CASC" ] && grep -q 'securityRealm' "$CASC" && grep -q 'agente-linux' "$CASC"; then
  ok "Configuración como código en $CASC (seguridad y nodos incluidos)."
else
  no "Falta CASC_JENKINS_CONFIG en el servicio, o el YAML no define securityRealm y el nodo agente-linux."
fi
if [ -n "$CASC" ] && [ -f "$CASC" ] && ! grep -q 'Deploy-Legacy-2026' "$CASC" \
   && ! grep -Eiq '^\s*(password|secret)\s*:\s*["'"'"']?[^"$'"'"' ]' "$CASC"; then
  ok "El YAML no lleva contraseñas en claro (usa \${...})."
else
  no "El YAML de JCasC lleva contraseñas literales: usa \${readFile:/ruta} o variables."
fi

# 4. Controlador sin ejecutores y agente propio.
NX=$(sed -n 's:.*<numExecutors>\(.*\)</numExecutors>.*:\1:p' "$J/config.xml" 2>/dev/null | head -1)
if [ "$NX" = 0 ]; then
  ok "El controlador tiene 0 ejecutores."
else
  no "El controlador tiene ${NX:-?} ejecutores (deben ser 0)."
fi
NODO=$J/nodes/agente-linux/config.xml
AG=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{print $1}' | while read -r s; do
  systemctl show "$s" -p ExecStart --value | grep -q 'agent.jar' && echo "$s"; done | head -1)
AU=$( [ -n "$AG" ] && systemctl show "$AG" -p User --value)
if [ -f "$NODO" ] && grep -q '<label>[^<]*linux' "$NODO" && grep -q 'webSocket>true' "$NODO" \
   && [ -n "$AG" ] && systemctl show "$AG" -p ExecStart --value | grep -q -- '-webSocket' \
   && [ -n "$AU" ] && [ "$AU" != root ]; then
  ok "agente-linux (label linux) conecta por WebSocket como servicio $AG, usuario '$AU'."
else
  no "Falta el nodo agente-linux con label linux y WebSocket, o su servicio (no root) con -webSocket."
fi

# 5. Builds: humo verde en el agente.
ultimo(){ local b; b=$(ls -1 "$J/jobs/$1/builds" 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -1); [ -n "$b" ] && echo "$J/jobs/$1/builds/$b"; }
H=$(ultimo humo)
if [ -n "$H" ] && grep -q '<result>SUCCESS' "$H/build.xml" 2>/dev/null && grep -aq 'Running on .*agente-linux' "$H/log" 2>/dev/null; then
  ok "El job humo acaba en verde en agente-linux."
else
  no "El último build de humo no está en verde en agente-linux."
fi

# 6. Credenciales.
L=$(ultimo despliegue-legacy)
CFG=$J/jobs/despliegue-legacy/config.xml
if grep -q '<id>deploy-pass</id>' "$J/credentials.xml" 2>/dev/null && ! grep -rq 'Deploy-Legacy-2026' "$J/credentials.xml"; then
  ok "Existe la credencial deploy-pass (cifrada en Jenkins)."
else
  no "No existe la credencial con id deploy-pass."
fi
if [ -f "$CFG" ] && ! grep -q 'Deploy-Legacy-2026' "$CFG" && grep -q 'deploy-pass' "$CFG" \
   && [ -n "$L" ] && grep -q '<result>SUCCESS' "$L/build.xml" && ! grep -q 'Deploy-Legacy-2026' "$L/log" \
   && tail -1 /var/log/publicador.log 2>/dev/null | grep -q '"ok": true'; then
  ok "despliegue-legacy usa deploy-pass, publica bien y el log no muestra la contraseña."
else
  no "despliegue-legacy sigue con la contraseña en claro, no usa deploy-pass, o su último build no publicó."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Jenkins con usuario propio, seguridad, JCasC, agente y credenciales."; exit 0; } || exit 1
