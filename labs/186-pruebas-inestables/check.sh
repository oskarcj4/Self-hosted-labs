#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/pedidos
NOMBRES="test_total_con_iva test_fecha_entrega test_repartir test_carrito_empieza_vacio test_anadir test_salud"
T=$(mktemp -d); chmod 777 "$T"

echo "== Lab 186 · Tests inestables — comprobación =="

# corre DIR [VAR=valor...] [-- prefijo]: ejecuta la suite como analista y
# deja en $R el resumen ("ok" o lo que falla).
corre(){
  local dir=$1; shift
  local envs=() pre=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do envs+=("$1"); shift; done
  [ "${1:-}" = -- ] && { shift; pre=("$@"); }
  rm -f "$T/j.xml"
  (cd "$dir" && runuser -u analista -- env PYTHONPATH=/opt/lab/tests PYTHONDONTWRITEBYTECODE=1 "${envs[@]}" \
     "${pre[@]}" timeout -k 5 90 python3 -m pytest -q -p barajar -p no:cacheprovider \
     --junitxml="$T/j.xml" > "$T/out" 2>&1)
  R=$(python3 /opt/lab/tests/junit.py "$T/j.xml" "$NOMBRES")
}

# 0. Sin trampas
TRAMPA=$(grep -rlniE 'rerun|flaky|retry|reintent|pytest\.mark\.(skip|xfail)|pytest\.(skip|xfail)\(|importorskip' \
          "$P/tests" "$P"/pytest.ini "$P"/conftest.py "$P"/setup.cfg "$P"/pyproject.toml "$P"/tox.ini 2>/dev/null)
if [ -z "$TRAMPA" ]; then
  ok "Sin reintentos, skip ni xfail."
else
  no "Hay reintentos/skip/xfail en: $(echo $TRAMPA | sed "s#$P/##g")."
fi

# 1. Orden normal
corre "$P"
[ "$R" = ok ] && ok "La suite pasa en el orden normal." || no "Orden normal: $R."

# 2. Orden inverso y barajado
MAL=""
corre "$P" BARAJAR=inverso; [ "$R" = ok ] || MAL="inverso → $R"
for s in 1 2 3 4 5 6; do
  [ -n "$MAL" ] && break
  corre "$P" BARAJAR=$s; [ "$R" = ok ] || MAL="barajado ($s) → $R"
done
[ -z "$MAL" ] && ok "Pasa en orden inverso y barajado (7 órdenes)." || no "Depende del orden: $MAL."

# 3. Semillas de random
MAL=""
for s in $(seq 0 29); do
  corre "$P" SEMILLA=$s; [ "$R" = ok ] || { MAL="semilla $s → $R"; break; }
done
[ -z "$MAL" ] && ok "Pasa con 30 semillas distintas de random." || no "Depende del azar: $MAL."

# 4. Hora y zona horaria
MAL=""
for f in '2026-03-10 00:30:00|Europe/Madrid' '2026-07-01 01:30:00|Europe/Madrid' \
         '2026-12-31 23:30:00|America/Mexico_City' '2026-06-15 12:00:00|UTC'; do
  corre "$P" TZ="${f#*|}" FAKETIME_DONT_FAKE_MONOTONIC=1 -- faketime "@${f%|*}"
  [ "$R" = ok ] || { MAL="${f%|*} en ${f#*|} → $R"; break; }
done
[ -z "$MAL" ] && ok "Pasa a cualquier hora (medianoche, cambio de día UTC/local)." || no "Depende de la hora: $MAL."

# 5. Puerto 8765 ocupado por otro proceso
python3 - <<'PY' &
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        b = json.dumps({"estado": "soy-otro-servicio"}).encode()
        self.send_response(200); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 8765), H).serve_forever()
PY
OCU=$!; sleep 0.7
corre "$P"
kill $OCU 2>/dev/null; wait $OCU 2>/dev/null
[ "$R" = ok ] && ok "Pasa con el puerto 8765 ocupado (puerto libre elegido por el SO)." || no "Con el puerto 8765 ocupado: $R."

# 6. Mutaciones: la suite debe detectar bugs reales
MUT=$T/mut
VIVOS=""
while IFS='|' read -r fich viejo nuevo desc; do
  rm -rf "$MUT"; cp -r "$P" "$MUT"; chown -R analista "$MUT"
  if ! python3 - "$MUT/$fich" "$viejo" "$nuevo" <<'PY'
import sys
p, a, b = sys.argv[1:]
s = open(p, encoding="utf-8").read()
if a not in s:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(a, b))
PY
  then VIVOS="$VIVOS; no encuentro '$viejo' en $fich (¿cambiaste la lógica de negocio?)"; continue; fi
  corre "$MUT"
  [ "$R" = ok ] && VIVOS="$VIVOS; nadie detecta: $desc"
done <<'M'
pedidos.py|timedelta(days=2)|timedelta(days=3)|la entrega pasa a 3 días
pedidos.py|return len(CARRITO)|return 1|anadir() siempre devuelve 1
pedidos.py|i % len(repartidores)|0|todos los pedidos van al primer repartidor
pedidos.py|IVA = 0.21|IVA = 0.10|el IVA baja al 10 %
servidor.py|"estado": "ok"|"estado": "degradado"|la salud responde "degradado"
M
[ -z "$VIVOS" ] && ok "La suite detecta los 5 bugs introducidos." || no "Mutaciones:${VIVOS#;}."
rm -rf "$T"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Verde significa verde: sin re-run."; exit 0; } || exit 1
