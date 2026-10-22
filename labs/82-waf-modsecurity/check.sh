#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 82.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 82 — comprobación =="

active(){ sudo grep -hiE "$1" /etc/modsecurity/*.conf 2>/dev/null | grep -vE '^\s*#'; }

# 1) Módulo cargado
if sudo apache2ctl -M 2>/dev/null | grep -qi security2; then
  ok "mod_security2 está cargado."
else
  no "Habilita el módulo (sudo a2enmod security2)."
fi

# 2) SecRuleEngine On (no DetectionOnly/Off)
if active '^\s*SecRuleEngine\s+On' >/dev/null; then
  ok "SecRuleEngine está On (modo bloqueo)."
else
  no "Pon SecRuleEngine On en /etc/modsecurity/modsecurity.conf."
fi

# 3) Config válida
if sudo apache2ctl -t 2>&1 | grep -qi 'Syntax OK'; then
  ok "La configuración de Apache es válida (Syntax OK)."
else
  no "apache2ctl -t no da 'Syntax OK'."
fi

# 4) Tráfico legítimo pasa (200)
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ 2>/dev/null)
if [ "$code" = "200" ]; then
  ok "El tráfico legítimo pasa (200)."
else
  no "El tráfico legítimo no responde 200 (reinicia Apache)."
fi

# 5) El WAF bloquea un ataque conocido (SQLi -> 403): CRS activo de extremo a extremo
atk=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1/?q=1%27+OR+%271%27=%271" 2>/dev/null)
if [ "$atk" = "403" ]; then
  ok "El WAF bloquea una inyección SQL de prueba (403)."
else
  no "El WAF no bloquea la inyección SQL de prueba (código $atk; ¿motor On y CRS cargado?)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 WAF activo y bloqueando capa 7. ¡Lab 82 resuelto!"; exit 0; } || exit 1
