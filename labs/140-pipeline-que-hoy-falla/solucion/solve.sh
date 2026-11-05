#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
ci-logs 41 | grep -i fastjson; ci-logs 42 | grep -i fastjson
printf 'paquete=fastjson\nversion_rota=2.0.0\n' > $H/causa.txt
chown analista:analista $H/causa.txt
runuser -u analista -- bash -s <<'SH'
set -e
cd ~/api
python3 -m venv /tmp/v
/tmp/v/bin/pip download -q fastjson==1.4.2 --no-deps -d /tmp/w
HASH=$(sha256sum /tmp/w/fastjson-1.4.2-py3-none-any.whl | cut -d' ' -f1)
echo "fastjson==1.4.2 --hash=sha256:$HASH" > requirements.lock
cat > ci/deps.sh <<'D'
#!/usr/bin/env bash
# Instala las dependencias reutilizando la caché del runner (/var/cache/ci).
# La clave depende del contenido del lockfile: otro lockfile, otra caché.
set -euo pipefail
CACHE_DIR=/var/cache/ci
KEY="venv-$(sha256sum requirements.lock | cut -c1-16)"
if [ -d "$CACHE_DIR/$KEY" ]; then
  echo "cache hit: $KEY"
else
  echo "cache miss: $KEY -> instalando"
  python3 -m venv "$CACHE_DIR/$KEY"
  "$CACHE_DIR/$KEY/bin/pip" install -q --require-hashes -r requirements.lock     || { rm -rf "${CACHE_DIR:?}/$KEY"; exit 1; }   # no dejes una caché a medias
fi
ln -sfn "$CACHE_DIR/$KEY" .venv
echo "dependencias en uso:"; .venv/bin/pip freeze
D
git rm -q requirements.txt
git add -A
git commit -qm "Build reproducible: requirements.lock con hash y caché por lockfile"
git push -q origin main
SH
sleep 20
ci-logs | tail -5
