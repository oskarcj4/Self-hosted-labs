#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 83.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 83 — comprobación =="

# Config efectiva de nginx (resuelve includes)
CFG="$(sudo nginx -T 2>/dev/null)"
active(){ printf '%s\n' "$CFG" | grep -iE "$1" | grep -vE '^\s*#'; }

# 1) zona de rate limit definida
if active '^\s*limit_req_zone\s' >/dev/null; then
  ok "Hay un limit_req_zone definido."
else
  no "Define un limit_req_zone en el contexto http (nginx.conf)."
fi

# 2) límite aplicado en una location
if active '^\s*limit_req\s+zone=' >/dev/null; then
  ok "Se aplica limit_req zone=... en el sitio."
else
  no "Aplica 'limit_req zone=... burst=... nodelay;' en la location."
fi

# 3) sigue siendo reverse proxy al backend
if active '^\s*proxy_pass\s+.*8080' >/dev/null; then
  ok "El proxy_pass al backend 127.0.0.1:8080 sigue en pie."
else
  no "Mantén el proxy_pass http://127.0.0.1:8080 en la location."
fi

# 4) config válida
if sudo nginx -t 2>&1 | grep -qi 'syntax is ok'; then
  ok "La configuración de nginx es válida (syntax is ok)."
else
  no "nginx -t no valida la configuración."
fi

# 5) sirviendo
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ 2>/dev/null)
if [ "$code" = "200" ]; then
  ok "El sitio responde 200 a través del proxy."
else
  no "El sitio no responde 200 (reinicia: sudo service nginx reload)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Reverse proxy con rate limit en pie. ¡Lab 83 resuelto!"; exit 0; } || exit 1
