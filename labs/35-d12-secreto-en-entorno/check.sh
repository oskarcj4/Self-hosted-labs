#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 35 (Día 12).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
AS_ANALISTA=""; [ "$(id -u)" -eq 0 ] && AS_ANALISTA="runuser -u analista --"
TOKEN="ing_live_4f7a9c2e8b1d6f3a5c0e"

echo "== Lab 35 · Día 12 — comprobación =="

if systemctl show ingest -p Environment --value | grep -qF "$TOKEN"; then
  no "El token sigue en Environment= (visible con: systemctl show ingest -p Environment)."
else
  ok "El token ya no está en el entorno declarado de la unidad."
fi

if $AS_ANALISTA systemctl cat ingest 2>/dev/null | grep -qF "$TOKEN"; then
  no "El token sigue escrito en la unidad o en un drop-in legible por todos (systemctl cat ingest)."
else
  ok "Ni la unidad ni sus drop-ins contienen el token."
fi

pid=$(systemctl show ingest -p MainPID --value)
if [ "${pid:-0}" -gt 0 ] && systemctl is-active --quiet ingest; then
  if $SUDO cat /proc/$pid/environ 2>/dev/null | tr '\0' '\n' | grep -qF "$TOKEN"; then
    no "El token sigue en el entorno del proceso (/proc/$pid/environ)."
  else
    ok "El proceso en ejecución no lleva el token en su entorno."
  fi
else
  no "ingest no está activo."
fi

h=$(curl -s --max-time 3 http://127.0.0.1:8700/)
if echo "$h" | grep -q "token valido" && ! echo "$h" | grep -q "origen: env"; then
  ok "ingest funciona con el token cargado desde fichero/credencial ($(echo "$h" | sed 's/.*origen: //;s/)//'))."
else
  no "ingest no tiene un token válido cargado desde fichero o credencial: ${h:-sin respuesta}"
fi

leak=""
for f in $(echo "$TOKEN" | $SUDO grep -rlsF --exclude-dir=journal -f - /etc /opt /home /srv /var/lib /run/credentials 2>/dev/null); do
  case "$f" in /opt/lab/*) continue ;; esac
  if $AS_ANALISTA test -r "$f" 2>/dev/null; then leak="$leak $f"; fi
done
if [ -z "$leak" ]; then ok "Ningún fichero con el token es legible por un usuario normal."
else no "El token es legible por usuarios normales en:$leak"; fi

if [ "$(systemctl show ingest -p User --value)" = "ingest" ]; then ok "ingest sigue corriendo como 'ingest'."
else no "ingest ya no corre como 'ingest'."; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Token fuera del entorno. ¡Día 12 resuelto!"; exit 0; } || exit 1
