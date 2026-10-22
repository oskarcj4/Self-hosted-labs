#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 80.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 80 — comprobación =="

FILES="/etc/apache2/apache2.conf"
for d in conf-enabled mods-enabled sites-enabled; do
  for f in /etc/apache2/$d/*.conf; do [ -f "$f" ] && FILES="$FILES $f"; done
done
active(){ sudo grep -hiE "$1" $FILES 2>/dev/null | grep -vE '^\s*#'; }
mods(){ sudo apache2ctl -M 2>/dev/null; }

# 1) mod_reqtimeout + RequestReadTimeout
if mods | grep -qi reqtimeout && active '^\s*RequestReadTimeout\s' >/dev/null; then
  ok "mod_reqtimeout activo con RequestReadTimeout."
else
  no "Falta habilitar mod_reqtimeout y poner un RequestReadTimeout."
fi

# 2) Timeout <= 30
tval=$(active '^\s*Timeout\s+[0-9]' | awk '{print $2}' | sort -n | head -1)
if [ -n "$tval" ] && [ "$tval" -le 30 ]; then
  ok "Timeout bajado a $tval (<=30)."
else
  no "Baja Timeout a 30 o menos (actual: ${tval:-sin definir})."
fi

# 3) KeepAliveTimeout <= 15
kval=$(active '^\s*KeepAliveTimeout\s+[0-9]' | awk '{print $2}' | sort -n | head -1)
if [ -n "$kval" ] && [ "$kval" -le 15 ]; then
  ok "KeepAliveTimeout bajado a $kval (<=15)."
else
  no "Baja KeepAliveTimeout a 15 o menos (actual: ${kval:-sin definir})."
fi

# 4) mod_evasive + DOSPageCount
if mods | grep -qi evasive && active '^\s*DOSPageCount\s' >/dev/null; then
  ok "mod_evasive activo y configurado (DOSPageCount)."
else
  no "Falta habilitar mod_evasive y configurarlo (DOSPageCount, DOSBlockingPeriod...)."
fi

# 5) Config válida
if sudo apache2ctl -t 2>&1 | grep -qi 'Syntax OK'; then
  ok "La configuración de Apache es válida (Syntax OK)."
else
  no "apache2ctl -t no da 'Syntax OK'."
fi

# 6) Sirviendo
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ 2>/dev/null)
if [ "$code" = "200" ]; then
  ok "Apache responde 200 en 127.0.0.1."
else
  no "Apache no responde 200 (reinícialo: sudo service apache2 restart)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Apache endurecido contra DoS. ¡Lab 80 resuelto!"; exit 0; } || exit 1
