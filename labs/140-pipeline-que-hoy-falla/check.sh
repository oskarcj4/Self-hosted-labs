#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 140.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
REPO=http://127.0.0.1:3000/analista/api.git
WHL=/srv/pypi/simple/fastjson/fastjson-1.4.2-py3-none-any.whl
BUENO=$(sha256sum "$WHL" | cut -d' ' -f1)
asgit(){ $SUDO -u git -H "$@"; }
[ -z "$SUDO" ] && asgit(){ runuser -u git -- "$@"; }

echo "== Lab 140 · El pipeline que hoy falla — comprobación =="
grep -qE '^paquete=fastjson\s*$' $H/causa.txt 2>/dev/null && grep -qE '^version_rota=2\.0\.0\s*$' $H/causa.txt \
  && ok "causa.txt: fastjson 2.0.0 rompió el build." || no "causa.txt: falta paquete=/version_rota= correctos."

T=$(mktemp -d); chmod 0755 "$T"
if git clone -q "$REPO" "$T/api" 2>/dev/null; then
  L="$T/api/requirements.lock"
  if [ -f "$L" ]; then
    grep -qE '^fastjson==1\.4\.2\b' "$L" && ok "requirements.lock fija fastjson==1.4.2 (en main)." || no "requirements.lock no fija fastjson==1.4.2."
    grep -q -- "--hash=sha256:$BUENO" "$L" && ok "El lockfile lleva el hash sha256 correcto de la wheel." || no "El lockfile no lleva el --hash=sha256 correcto de fastjson 1.4.2."
  else
    no "No hay requirements.lock en main (¿hiciste push?)."
  fi
  D="$T/api/ci/deps.sh"
  grep -q -- '--require-hashes' "$D" && grep -q 'requirements.lock' "$D" \
    && ok "ci/deps.sh instala con --require-hashes desde requirements.lock." || no "ci/deps.sh no instala con --require-hashes -r requirements.lock."

  # La clave de caché debe depender del lockfile: si el lockfile cambia,
  # deps.sh debe crear una entrada nueva en /var/cache/ci.
  if [ -f "$L" ]; then
    chown -R git:git "$T" 2>/dev/null || $SUDO chown -R git:git "$T"
    asgit bash -c "cd '$T/api' && CI_COMMIT_BRANCH=main bash ci/deps.sh" >/dev/null 2>&1
    antes=$($SUDO ls /var/cache/ci | wc -l)
    asgit bash -c "cd '$T/api' && echo '# prueba $RANDOM$$' >> requirements.lock && CI_COMMIT_BRANCH=main bash ci/deps.sh" >/dev/null 2>&1
    despues=$($SUDO ls /var/cache/ci | wc -l)
    [ "$despues" -gt "$antes" ] && ok "La clave de caché cambia al cambiar requirements.lock." \
      || no "Cambiar requirements.lock no crea otra entrada de caché: la clave no depende del lockfile."
  fi
else
  no "No pude clonar $REPO."
fi
$SUDO rm -rf "$T"

# Push a main → el hook lanzó un pipeline en verde para el HEAD actual.
HEAD=$(git ls-remote "$REPO" refs/heads/main | cut -f1)
for _ in $(seq 1 60); do $SUDO grep -q "^[0-9]* $HEAD " /var/lib/ci/historial && break; sleep 2; done
$SUDO grep -q "^[0-9]* $HEAD success" /var/lib/ci/historial \
  && ok "El push a main lanzó un pipeline que pasó (${HEAD:0:8})." || no "No hay pipeline en verde lanzado por push para el HEAD de main."

# Caché envenenada con la clave vieja (rama): el pipeline debe ignorarla.
$SUDO rm -rf /var/cache/ci/venv-main
asgit python3 -m venv /var/cache/ci/venv-main >/dev/null 2>&1
asgit /var/cache/ci/venv-main/bin/pip install -q fastjson==2.0.0 >/dev/null 2>&1
if $SUDO /usr/local/bin/ci-run >/dev/null 2>&1; then ok "Con una caché vieja envenenada, el pipeline sigue en verde."
else no "Con una caché vieja envenenada (venv-main con 2.0.0) el pipeline falla."; fi
antes=$($SUDO ls /var/cache/ci | wc -l)
if $SUDO /usr/local/bin/ci-run >/dev/null 2>&1 && [ "$($SUDO ls /var/cache/ci | wc -l)" = "$antes" ]; then
  ok "Segundo pipeline con el mismo lockfile: reutiliza la caché."
else no "El segundo pipeline falla o no reutiliza la caché (crea otra entrada)."; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Build reproducible y caché que no miente."; exit 0; } || exit 1
