#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 81.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 81 — comprobación =="

FILES="/etc/apache2/apache2.conf"
for f in /etc/apache2/mods-enabled/*.conf /etc/apache2/conf-enabled/*.conf; do [ -f "$f" ] && FILES="$FILES $f"; done
active(){ sudo grep -hiE "$1" $FILES 2>/dev/null | grep -vE '^\s*#'; }

# 1) mod_reqtimeout cargado
if sudo apache2ctl -M 2>/dev/null | grep -qi reqtimeout; then
  ok "mod_reqtimeout está cargado."
else
  no "Habilita mod_reqtimeout (sudo a2enmod reqtimeout)."
fi

# 2) RequestReadTimeout con límite de cabeceras
if active '^\s*RequestReadTimeout\b.*header=' >/dev/null; then
  ok "Hay un RequestReadTimeout con límite de cabeceras (header=...)."
else
  no "Añade RequestReadTimeout con un límite 'header=' (p.ej. header=20-40,MinRate=500)."
fi

# 3) Config válida
if sudo apache2ctl -t 2>&1 | grep -qi 'Syntax OK'; then
  ok "La configuración de Apache es válida (Syntax OK)."
else
  no "apache2ctl -t no da 'Syntax OK'."
fi

# 4) Sirviendo
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ 2>/dev/null)
if [ "$code" = "200" ]; then
  ok "Apache responde 200 en 127.0.0.1."
else
  no "Apache no responde 200 (reinícialo: sudo service apache2 restart)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Slowloris mitigado con mod_reqtimeout. ¡Lab 81 resuelto!"; exit 0; } || exit 1
