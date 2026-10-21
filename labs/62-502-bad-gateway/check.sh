#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 62. Peticiones reales a través de nginx.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
get(){ curl -s -o /tmp/.c62 -w '%{http_code}' --max-time "$2" "http://127.0.0.1$1"; }

echo "== Lab 62 · 502 / 403 / 504 — comprobación =="

$SUDO nginx -t >/dev/null 2>&1 && ok "Config de nginx válida." || no "nginx -t falla."

grep -qE '^PORT=8001$' /etc/gestion/gestion.env && [ "$(systemctl is-active gestion)" = active ] \
  && ok "gestion sigue en el puerto de la v2 (8001): el arreglo está en el proxy, no en la app." \
  || no "gestion debe seguir activo y con PORT=8001 (el cambio de puerto es intencionado)."

c=$(get / 5)
[ "$c" = 200 ] && grep -q 'gestion ok' /tmp/.c62 && ok "/ responde 200 a través de nginx." \
  || no "/ responde $c (502 = nginx no conecta con el upstream)."

c=$(get /static/logo.txt 5)
[ "$c" = 200 ] && grep -q 'logo-gestion-v2' /tmp/.c62 && ok "/static/logo.txt responde 200." \
  || no "/static/logo.txt responde $c (403 = nginx no puede leer el fichero)."

bad=$($SUDO find /srv/gestion -perm -o+w 2>/dev/null | head -1)
[ -z "$bad" ] && ok "Nada en /srv/gestion es escribible por todos." \
  || no "$bad es escribible por cualquiera: nginx necesita leer, no escribir (nada de 777)."

echo "  (pidiendo /api/informe, tarda ~12 s...)"
c=$(get /api/informe 25)
[ "$c" = 200 ] && grep -q 'informe listo' /tmp/.c62 && ok "/api/informe responde 200." \
  || no "/api/informe responde $c (504 = nginx se cansó de esperar al upstream)."

# El timeout largo sólo donde hace falta: el resto debe fallar rápido.
conf=$($SUDO nginx -T 2>/dev/null)
glob=$(echo "$conf" | awk '/location \/ \{/{f=1} f&&/proxy_read_timeout/{print $2; exit} f&&/\}/{f=0}' | tr -dc '0-9')
if [ -n "$glob" ] && [ "$glob" -le 10 ]; then
  ok "El timeout general sigue siendo corto (${glob}s); el largo sólo afecta al informe."
else
  no "Subiste proxy_read_timeout para todo '/' (${glob:-por defecto 60}s): ponlo largo sólo en location /api/informe."
fi
rm -f /tmp/.c62

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Proxy corregido: 502, 403 y 504 resueltos."; exit 0; } || exit 1
