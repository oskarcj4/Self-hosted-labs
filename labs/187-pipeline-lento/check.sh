#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
A=/home/analista/api
LIMITE=25
T=$(mktemp -d); chmod 755 "$T"; C=$T/api
como(){ runuser -u analista -- "$@"; }
pipeline(){ como ci-run "$C" > "$T/ci.log" 2>&1; R=$?; DUR=$(cat /var/lib/ci/ultima-duracion 2>/dev/null || echo 999); return $R; }
commit(){ (cd "$C" && como git add -A && como git commit -qm "$1"); }

echo "== Lab 187 · Pipeline lento — comprobación =="

if [ -n "$(git -C $A status --porcelain 2>/dev/null)" ]; then
  echo "  (aviso: hay cambios sin commit en ~/api; el check usa el último commit)"
fi
if [ "$(git -C $A ls-files datos | wc -l)" -ge 3 ]; then
  ok "Los datos siguen en el repo (no se arregla borrándolos)."
else
  no "Faltan los ficheros de datos/ en el repo: no hay que borrarlos, sino dejarlos fuera de la imagen."
fi
if grep -q -- '--no-cache' $A/.woodpecker.yaml 2>/dev/null; then
  no "El build sigue con --no-cache."
else
  ok "El build no usa --no-cache."
fi

como git clone -q "$A" "$C" 2>/dev/null
echo "  ... pipeline de calentamiento (último commit; puede tardar si nada está en caché)"
if pipeline; then
  ok "El pipeline del último commit pasa (${DUR} s)."
else
  no "El pipeline del último commit falla (ci-logs para ver por qué)."
fi

# 1. Commit que sólo toca código
MARCA="9.9.$RANDOM"
sed -i "s/^VERSION = .*/VERSION = \"$MARCA\"/" "$C/app.py"; commit "solo código"
SHA=$(git -C "$C" rev-parse HEAD)
if pipeline && [ "$DUR" -lt "$LIMITE" ]; then
  ok "Commit de sólo código: ${DUR} s (< ${LIMITE} s)."
else
  no "Commit de sólo código: $([ $R = 0 ] && echo "${DUR} s (objetivo < ${LIMITE} s)" || echo "pipeline en rojo")."
fi
V=$(docker run --rm "api:$SHA" python -c 'import app; print(app.VERSION)' 2>/dev/null)
[ "$V" = "$MARCA" ] && ok "La imagen api:<sha> lleva el código nuevo." \
                    || no "La imagen api:${SHA:0:12}… no lleva el código del commit (VERSION='${V:-sin imagen}')."

# 2. Contexto e imagen
CTX=$(cd "$C" && DOCKER_BUILDKIT=1 docker build --progress=plain -t chk187 . 2>&1 \
      | sed -n 's/.*transferring context: \([0-9.]*\)\([kMG]*B\).*/\1 \2/p' | tail -1)
CTXMB=$(echo "$CTX" | awk '{v=$1; u=$2; if(u=="kB")v/=1024; else if(u=="GB")v*=1024; else if(u=="B")v/=1048576; printf "%d", v}')
if [ -n "$CTX" ] && [ "${CTXMB:-999}" -lt 5 ]; then
  ok "Contexto de build pequeño: $CTX."
else
  no "Contexto de build: ${CTX:-desconocido} (los datos y .git no deben enviarse al build)."
fi
if docker run --rm "api:$SHA" sh -c 'test ! -e /app/datos && test ! -e /app/.git' 2>/dev/null; then
  ok "La imagen no lleva datos/ ni .git."
else
  no "La imagen lleva datos/ o .git dentro."
fi
docker rmi -f chk187 >/dev/null 2>&1

# 3. Cambia requirements.txt: hay que reinstalar
echo "asn1crypto==1.5.1" >> "$C/requirements.txt"
cat > "$C/tests/test_dep_nueva.py" <<'PY'
import unittest


class TestDependenciaNueva(unittest.TestCase):
    def test_importa(self):
        import asn1crypto  # noqa: F401
PY
commit "nueva dependencia"
SHA2=$(git -C "$C" rev-parse HEAD)
if pipeline; then
  if docker run --rm "api:$SHA2" python -c 'import asn1crypto' 2>/dev/null; then
    ok "Con requirements.txt nuevo se reinstalan las dependencias (tests e imagen)."
  else
    no "Pipeline verde, pero la imagen no tiene la dependencia nueva (caché de capas mal ordenada)."
  fi
else
  no "Al añadir una dependencia a requirements.txt el pipeline falla: la caché no se invalida (ci-logs)."
fi

# 4. Un test roto sigue poniendo el pipeline en rojo
sed -i 's/"2026-01-08")   # lunes/"2026-01-09")   # lunes/' "$C/tests/test_app.py"; commit "test roto"
if pipeline; then
  no "Un test roto deja el pipeline en verde."
else
  grep -q 'FAIL\|AssertionError' "$T/ci.log" && ok "Un test roto pone el pipeline en rojo." \
                                          || no "El pipeline falla con un test roto, pero no por el test (revisa ci-logs)."
fi

docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "api:($SHA|$SHA2)" | xargs -r docker rmi -f >/dev/null 2>&1
rm -rf "$T"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 De un minuto a unos segundos, sin cachés mentirosas."; exit 0; } || exit 1
