#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
APP=/opt/allsafe/app.py
ENVF=/etc/allsafe/app.env
UNIT=/etc/systemd/system/allsafe-api.service

echo "== Lab 153 · Configuración por ambiente — comprobación =="

# 1) Sin secreto quemado en el código
if $SUDO grep -q 's3cr3t-allsafe-prod-KEY' "$APP" 2>/dev/null; then
  no "El secreto sigue quemado en app.py (sácalo a la variable de entorno)."
else
  ok "No hay secreto quemado en app.py."
fi

# 2) La config se lee del entorno
if $SUDO grep -q 'os.environ' "$APP" 2>/dev/null \
   && $SUDO grep -q 'SECRET_KEY' "$APP" 2>/dev/null \
   && $SUDO grep -q 'APP_ENV' "$APP" 2>/dev/null; then
  ok "La app lee la configuración del entorno (os.environ)."
else
  no "app.py debe leer APP_ENV/SECRET_KEY/... con os.environ."
fi

# 3) EnvironmentFile con permisos 600
if $SUDO test -f "$ENVF"; then
  PERM=$($SUDO stat -c '%a' "$ENVF" 2>/dev/null)
  if $SUDO grep -q 'APP_ENV=prod' "$ENVF" && $SUDO grep -q 'SECRET_KEY=' "$ENVF"; then
    if [ "$PERM" = "600" ]; then
      ok "/etc/allsafe/app.env con APP_ENV=prod y SECRET_KEY, permisos 600."
    else
      no "/etc/allsafe/app.env debe tener permisos 600 (ahora $PERM)."
    fi
  else
    no "/etc/allsafe/app.env debe definir APP_ENV=prod y SECRET_KEY."
  fi
else
  no "Falta /etc/allsafe/app.env."
fi

# 4) El servicio usa EnvironmentFile
if $SUDO grep -q "EnvironmentFile=$ENVF" "$UNIT" 2>/dev/null; then
  ok "allsafe-api.service carga el EnvironmentFile."
else
  no "Añade EnvironmentFile=$ENVF al servicio."
fi

# 5) En ejecución reporta prod y secret puesto
OUT=$(curl -s --max-time 3 localhost:8080/ 2>/dev/null)
if echo "$OUT" | grep -q '"env": *"prod"' && echo "$OUT" | grep -q '"secret_set": *true'; then
  ok "El servicio en marcha reporta env=prod y secret_set=true."
else
  no "El servicio no responde con env=prod/secret_set=true (¿reiniciaste tras los cambios?)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Misma imagen, config por entorno, secreto fuera del código."; exit 0; } || exit 1
