# Resolución guiada · Lab 140

:::piensa Antes de tocar nada
"Nadie tocó el código" casi siempre es verdad. Lo que cambia sin commit son
las dependencias que se resuelven en cada build, la imagen base, la caché o
el propio runner. Compara el build verde con el rojo antes de cambiar nada.
:::

## Paso 1 · ¿Qué cambió entre #41 y #42?

:::pista Cómo comprobarlo
```bash
ci-logs -l
ci-logs 41 | grep -A3 'dependencias en uso'
ci-logs 42 | grep -A3 'dependencias en uso'
ci-logs 42 | grep -B2 AttributeError
ls -l --time-style=full-iso /srv/pypi/simple/fastjson/
```
#41 usó `fastjson==1.4.2`; #42, `2.0.0`, publicado esta madrugada.
`requirements.txt` dice `fastjson>=1.0`: cualquier versión nueva entra sola.
:::

## Paso 2 · ¿Por qué ayer no se instaló la 2.0.0?

**Pregúntate:** ¿cuándo instala `ci/deps.sh` y cuándo reutiliza?

:::pista Cómo comprobarlo
```bash
cat ~/api/ci/deps.sh
cat /var/log/ci/cache-clean.log
```
La clave es `venv-main`. Mientras existió la caché de ayer, nadie
resolvía versiones. La limpieza nocturna la borró y #42 resolvió de nuevo.
Y ahora `venv-main` contiene la 2.0.0: aunque fijes la versión, con esa
clave seguirás usando la caché rota.
:::

## Paso 3 · Lockfile con hash

:::pista Cómo hacerlo
```bash
cd ~/api
python3 -m venv /tmp/v
/tmp/v/bin/pip download fastjson==1.4.2 --no-deps -d /tmp/w
sha256sum /tmp/w/fastjson-1.4.2-py3-none-any.whl
echo "fastjson==1.4.2 --hash=sha256:<hash>" > requirements.lock
```
Con `--require-hashes`, pip rechaza cualquier fichero cuyo hash no
coincida: si alguien republica la 1.4.2 con otro contenido, el build falla.
En proyectos grandes el lockfile lo genera `pip-compile --generate-hashes`
(o `uv pip compile`, `poetry lock`, `npm ci` con `package-lock.json`).
:::

## Paso 4 · Clave de caché

**Pregúntate:** ¿qué debe cambiar para que la caché deje de valer?

:::pista Cómo hacerlo
Exactamente lo que determina su contenido: el lockfile.
```bash
KEY="venv-$(sha256sum requirements.lock | cut -c1-16)"
"$CACHE_DIR/$KEY/bin/pip" install -q --require-hashes -r requirements.lock
```
Es lo mismo que `hashFiles('**/requirements.lock')` en GitHub Actions o
`key: files:` en GitLab CI.
:::

## Paso 5 · Push y verde

:::pista Cómo comprobarlo
```bash
git add -A && git commit -m "Build reproducible" && git push
ci-logs            # espera unos segundos
```
:::

## Cómo actuar en una situación así

- Diff de entornos, no de código: versiones instaladas, imagen base, runner.
- Rangos abiertos (`>=`) en el manifiesto; versión exacta + hash en el lock.
  Las actualizaciones entran por PR (Renovate/Dependabot), con su pipeline.
- Una caché es una optimización: si su clave no describe su contenido, es un bug.

## Si te atascas

- `pip download` falla fuera del venv: Debian 12 no deja usar el pip del sistema; crea un venv.
- `THESE PACKAGES DO NOT MATCH THE HASHES`: copiaste mal el hash.
- El pipeline no arranca al hacer push: `ci-run` lo lanza a mano.
