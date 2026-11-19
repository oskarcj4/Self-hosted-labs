# Resolución guiada · Lab 214

:::piensa ¿Qué significa un pipeline en verde?
Sólo lo que comprueba. Un verde con 0 tests ejecutados no dice nada. Antes de
tocar nada, abre el log de la última ejecución y cuenta: ¿cuántos *passed*?
¿cuántos *skipped*? ¿Hay algún paso que no pueda fallar?
:::

## Paso 1 · Lee el verde

:::pista Cómo hacerlo
```bash
ci-estado
ci-log | grep -E 'passed|skipped|continue'
```
`4 skipped`: el `skipif` de los tests mira `DATABASE_URL`, y el workflow no la define.
:::

## Paso 2 · Prepara un entorno para probar en tu terminal

El pipeline instala sus dependencias en un entorno virtual (`.venv`) que vive
en el runner, no en tu terminal. En tu terminal **no hay** `pytest`, `ruff`
ni `fastapi` instalados, y tampoco existe el comando `python` (en Debian sólo
hay `python3`). Por eso `python -m pytest` falla tal cual:

```
bash: python: command not found
/usr/bin/python3: No module named pytest
```

Instálalos en un `.venv` dentro del repo, igual que hace el pipeline. No hace
falta internet: `pip` usa el mirror interno `/opt/wheels` (lo configura
`/etc/pip.conf`).

```bash
cd ~/tareas
python3 -m venv .venv
.venv/bin/pip install -r backend/requirements-dev.txt
.venv/bin/python -m pytest --version     # pytest 8.3.4
```

:::ojo No uses `sudo pip install` ni `pip install --break-system-packages`
Debian protege el Python del sistema (PEP 668: *externally-managed-environment*).
Un `.venv` por proyecto es lo correcto, y `.venv/` ya está en `.gitignore`:
no se sube al repo.
:::

A partir de aquí, `pytest`, `ruff` y `python` significan **los del `.venv`**.
Desde `backend/` se llaman con `../.venv/bin/...`. Si lo prefieres, activa el
entorno con `source ~/tareas/.venv/bin/activate` y escribe sólo `python`,
`pytest` o `ruff`.

## Paso 3 · Tests contra PostgreSQL

Primero reprodúcelo en tu terminal, con la base de CI:

```bash
cd ~/tareas/backend
../.venv/bin/pytest -v                    # 4 skipped: sin DATABASE_URL
export DATABASE_URL=postgresql://ci:ci@127.0.0.1:5432/tareas_test
../.venv/bin/pytest -v                    # ¿y ahora?
```

:::piensa Ahora fallan con ModuleNotFoundError: No module named 'app'
Nunca se habían ejecutado, así que nadie lo vio. El binario `pytest` no mete
el directorio actual en `sys.path`; `python -m pytest` sí:

```bash
../.venv/bin/python -m pytest -v          # 4 passed
```

También vale `pythonpath = ["."]` en `[tool.pytest.ini_options]` de
`backend/pyproject.toml`, y entonces el binario `pytest` también funciona.
:::

:::pista Cómo llevarlo al pipeline
En GitHub usarías `services: postgres:`; eso necesita Docker. Aquí, la base de CI:
```yaml
jobs:
  test:
    runs-on: self-hosted
    env:
      DATABASE_URL: postgresql://ci:ci@127.0.0.1:5432/tareas_test
    steps:
      # ...
      - name: Tests
        run: cd backend && ../.venv/bin/python -m pytest -v
```
Y quita `continue-on-error`.
:::

## Paso 4 · Lint

```bash
cd ~/tareas
.venv/bin/ruff check backend
```

:::pista Qué encuentra y cómo llevarlo al pipeline
Un `F821 Undefined name` en `marcar_hecha`: el 404 hace referencia a una
variable que no existe, así que en vez de un 404 sale un `NameError` y un
500. Corrígelo en `backend/app/main.py` y vuelve a pasar ruff hasta ver
`All checks passed!`. En el workflow, añade un paso antes de los tests:
```yaml
      - name: Lint
        run: .venv/bin/ruff check backend
```
:::

## Paso 5 · Frontend y despliegue

Si quieres probar el build en tu terminal (npm funciona sin internet, con la
caché interna):

```bash
cd ~/tareas/frontend && npm ci && npm run build && ls dist
```

:::pista Cómo hacerlo en el pipeline
Un job `deploy` con `needs: test` y sólo para `main`:
```yaml
  deploy:
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: cd frontend && npm ci && npm run build && cp -r dist ../backend/static
      - run: sudo /usr/local/bin/desplegar-tareas "$PWD" "${{ github.sha }}"
```
Cada job empieza en un directorio limpio: el build del frontend tiene que
estar en el mismo job que el despliegue (o pasarse como artefacto).
:::

## Paso 6 · Sube y comprueba

```bash
cd ~/tareas
git status                 # .venv/, node_modules/ y dist/ no deben aparecer
git add -A && git commit -m "ci: lint, tests con PostgreSQL y despliegue sólo desde main"
git push origin main
ci-estado                  # espera a que termine
ci-log | grep -E 'passed|skipped|All checks'
curl -s http://localhost:8080/api/salud
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- Desconfía de los pipelines que nunca fallan: cuenta los tests en el log.
- `continue-on-error` y los `skip` silenciosos convierten la CI en decoración.
- Si un test necesita una dependencia (una base de datos), dásela en la CI;
  no lo saltes "porque falla".
- Reproduce la CI en local con el mismo entorno (un `.venv` con
  `requirements-dev.txt`) antes de empujar: ahorra vueltas al pipeline.
