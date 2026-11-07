#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 159.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
A=/home/analista/api
img(){ docker inspect -f '{{.Config.Image}}' api 2>/dev/null; }
healthy(){ for _ in $(seq 1 10); do curl -fs http://127.0.0.1:8080/health >/dev/null && return 0; sleep 1; done; return 1; }
tag_exists(){ curl -fs http://127.0.0.1:5000/v2/api/tags/list 2>/dev/null | grep -q "\"$1\""; }
# clon de prueba con un cambio y un commit: tmp_commit <dir> <mensaje> <comando>
tmp_commit(){ rm -rf "$1"; git clone -q "$A" "$1" && (cd "$1" && eval "$3" \
  && git -c user.name=check -c user.email=check@lab add -A && git -c user.name=check -c user.email=check@lab commit -qm "$2"); }

echo "== Lab 159 · Pipeline completo — comprobación =="

# 1) Steps y orden
ORDER=$(python3 - "$A/.woodpecker.yaml" <<'PY' 2>/dev/null
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
s = d.get("steps", [])
names = [x.get("name") for x in s] if isinstance(s, list) else list(s.keys())
print(" ".join(n for n in names if n in ("test", "scan", "build", "publish", "deploy")))
PY
)
if [ "$ORDER" = "test scan build publish deploy" ]; then
  ok "Steps en orden: test → scan → build → publish → deploy."
else
  no "Se esperaban los steps test, scan, build, publish, deploy en ese orden. Hay: '${ORDER:-ninguno}'."
fi

# 2) Sin secretos en el código
if [ -z "$(git -C "$A" status --porcelain 2>/dev/null)" ] && gitleaks dir "$A" --no-banner >/dev/null 2>&1 \
   && ! grep -q 'ghp_' "$A/config.py" 2>/dev/null; then
  ok "gitleaks limpio y todo commiteado (token fuera de config.py)."
else
  no "Quita el token de config.py, haz commit de todo y deja 'gitleaks dir ~/api' sin hallazgos."
fi

# 3) Pipeline verde sobre HEAD: imagen por commit, publicada y desplegada
SHA=$(git -C "$A" rev-parse HEAD 2>/dev/null); T12=${SHA:0:12}
if ci-run "$A" >/tmp/ci159-ok.log 2>&1 && tag_exists "$T12" \
   && [ "$(img)" = "localhost:5000/api:$T12" ] && healthy; then
  ok "Pipeline verde: localhost:5000/api:$T12 publicada y en producción, /health OK."
  GOOD=1
else
  no "El pipeline sobre HEAD debe pasar, publicar localhost:5000/api:$T12 y dejarla corriendo como 'api' (tail /tmp/ci159-ok.log)."
  GOOD=0
fi

# 4) Un commit que rompe las pruebas no publica nada
if [ "$GOOD" = 1 ] && tmp_commit /tmp/c159-test "rompe pruebas" \
     "sed -i 's/return {\"status\": \"ok\"}/return {\"status\": \"ko\"}/' app.py"; then
  S=$(git -C /tmp/c159-test rev-parse HEAD); S12=${S:0:12}
  if ! ci-run /tmp/c159-test >/tmp/ci159-test.log 2>&1 && ! tag_exists "$S12" \
     && [ "$(img)" = "localhost:5000/api:$T12" ]; then
    ok "Con pruebas rotas el pipeline falla antes de publicar y producción no cambia."
  else
    no "Un commit con pruebas rotas no debe publicar ni desplegar (tail /tmp/ci159-test.log)."
  fi
else
  no "No se pudo probar el caso de pruebas rotas (antes deja el pipeline en verde)."
fi

# 5) Un commit que rompe el arranque provoca rollback
if [ "$GOOD" = 1 ] && tmp_commit /tmp/c159-boot "rompe arranque" \
     "echo 'ENV PORT=9090' >> Dockerfile"; then
  if ! ci-run /tmp/c159-boot >/tmp/ci159-boot.log 2>&1 && [ "$(img)" = "localhost:5000/api:$T12" ] && healthy; then
    ok "Con el arranque roto el deploy hace rollback: sigue la imagen $T12 y /health OK."
  else
    no "Si /health no responde, deploy debe volver a la imagen anterior y fallar (corre: $(img); tail /tmp/ci159-boot.log)."
  fi
else
  no "No se pudo probar el caso de arranque roto (antes deja el pipeline en verde)."
fi
rm -rf /tmp/c159-test /tmp/c159-boot

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Pipeline completo: probar, escanear, publicar, desplegar y volver atrás solo."; exit 0; } || exit 1
