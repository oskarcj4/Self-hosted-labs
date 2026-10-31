#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 127.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
C=/home/analista/codigos.txt
val(){ grep -E "^$1=" $C 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r'; }

echo "== Lab 127 · HTTP con curl — comprobación =="
bad=""
for kv in catalogo=301 admin=403 interno=401 no_existe=404 pedidos=502; do
  [ "$(val ${kv%=*})" = "${kv#*=}" ] || bad="$bad ${kv%=*}"
done
[ -z "$bad" ] && ok "Códigos HTTP correctos (301, 403, 401, 404, 502)." || no "codigos.txt: revisa el código de:$bad"
case "$(val redireccion)" in
  /productos|http://tienda.lab/productos) ok "Redirección leída de la cabecera Location." ;;
  *) no "codigos.txt: redireccion= no es el destino de /catalogo." ;;
esac

$SUDO nginx -t >/dev/null 2>&1 && ok "nginx -t: configuración válida." || no "nginx -t falla."
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://tienda.lab/api/pedidos)
[ "$code" = 200 ] && ok "/api/pedidos responde 200." || no "/api/pedidos responde $code (debe ser 200)."
curl -s --max-time 10 http://tienda.lab/api/pedidos | grep -q '"pedidos"' && ok "La respuesta es el JSON de la API." || no "/api/pedidos no devuelve el JSON del backend."
systemctl is-active -q pedidos-api && ok "El backend sigue en su sitio (pedidos-api activo)." || no "pedidos-api no está activo."
t=$(val ttfb_pedidos | tr ',' '.')
if python3 -c "import sys; t=float(sys.argv[1]); sys.exit(0 if 1.0 <= t <= 3.0 else 1)" "$t" 2>/dev/null; then
  ok "ttfb_pedidos=$t s (la API tarda >1 s: problema de backend, no de red)."
else
  no "codigos.txt: ttfb_pedidos= no es un tiempo medido de /api/pedidos ya arreglado."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 HTTP leído y API reparada."; exit 0; } || exit 1
