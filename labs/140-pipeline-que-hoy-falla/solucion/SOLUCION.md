# Solución — El pipeline que hoy falla

## Qué pasaba

1. `requirements.txt` pedía `fastjson>=1.0`. Esta madrugada se publicó
   `fastjson 2.0.0` en el mirror, que elimina `dumps_pretty()`.
2. La caché del CI tenía clave `venv-<rama>`. Ayer había caché (con 1.4.2) y
   nadie resolvía versiones. La limpieza nocturna la borró; #42 instaló la
   2.0.0 y la guardó en `venv-main`.
3. Aunque fijes la versión, con esa clave el CI seguiría usando la caché rota.

## Arreglo

```bash
printf 'paquete=fastjson\nversion_rota=2.0.0\n' > ~/causa.txt
cd ~/api
python3 -m venv /tmp/v
/tmp/v/bin/pip download -q fastjson==1.4.2 --no-deps -d /tmp/w
echo "fastjson==1.4.2 --hash=sha256:$(sha256sum /tmp/w/fastjson-1.4.2-py3-none-any.whl | cut -d' ' -f1)" > requirements.lock
git rm -q requirements.txt

cat > ci/deps.sh <<'D'
#!/usr/bin/env bash
# La clave depende del contenido del lockfile: otro lockfile, otra caché.
set -euo pipefail
CACHE_DIR=/var/cache/ci
KEY="venv-$(sha256sum requirements.lock | cut -c1-16)"
if [ -d "$CACHE_DIR/$KEY" ]; then
  echo "cache hit: $KEY"
else
  echo "cache miss: $KEY -> instalando"
  python3 -m venv "$CACHE_DIR/$KEY"
  "$CACHE_DIR/$KEY/bin/pip" install -q --require-hashes -r requirements.lock \
    || { rm -rf "${CACHE_DIR:?}/$KEY"; exit 1; }
fi
ln -sfn "$CACHE_DIR/$KEY" .venv
echo "dependencias en uso:"; .venv/bin/pip freeze
D

git add -A && git commit -m "Build reproducible: lockfile con hash y caché por lockfile"
git push
sleep 15; ci-logs | tail -3
bash /opt/lab/check.sh
```

## Más allá del lab

- Adaptar el código a la API nueva (`dumps(obj, pretty=True)`) es el
  siguiente paso, en su propio PR, subiendo el lockfile a 2.0.0.
- Fija también la imagen del runner/step por digest (`image: python@sha256:...`).
- Un mirror interno (Nexus, Artifactory, devpi) con cuarentena de versiones
  nuevas da margen antes de que lleguen a los builds.
