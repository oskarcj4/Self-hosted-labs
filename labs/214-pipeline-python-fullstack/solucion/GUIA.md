# Resolución guiada · Lab 214

:::piensa ¿Qué significa un pipeline en verde?
Sólo lo que comprueba. Un verde con 0 tests ejecutados no dice nada. Antes de
tocar nada, abre el log de la última ejecución y cuenta: ¿cuántos *passed*?
¿cuántos *skipped*? ¿Hay algún paso que no pueda fallar?
:::

**El plan:** (1) leer el verde, (2) preparar un entorno para probar en tu
terminal, (3) hacer que los tests corran contra PostgreSQL, (4) pasar el
linter y arreglar lo que encuentre, (5) reescribir el workflow y (6) subirlo.

## Paso 1 · Lee el verde

**Objetivo:** demostrar que el verde actual no comprueba nada.

:::pista Cómo hacerlo
```bash
ci-estado
ci-log | grep -E 'passed|skipped|continue'
cat ~/tareas/.github/workflows/ci.yml
```
`ci-estado` y `ci-log` son comandos del lab: el primero lista las
ejecuciones del pipeline y el segundo enseña el log de la última.

**Qué deberías ver:** `4 skipped` y un paso de tests con
`continue-on-error: true`. Hay dos trampas juntas:

- Los tests llevan `pytest.mark.skipif(not os.environ.get("DATABASE_URL"))`:
  si la variable no existe, se **saltan**, y un test saltado no cuenta como
  fallo. El workflow no la define.
- `continue-on-error: true` hace que, aunque el paso falle, el job siga y
  termine en verde.
:::

## Paso 2 · Un entorno para probar en tu terminal

**Objetivo:** ejecutar los tests y el linter aquí, igual que el pipeline,
para no ir a ciegas empujando commits.

:::pista Cómo hacerlo
En tu terminal no hay `pytest`, ni `ruff`, ni el comando `python` (en Debian
sólo existe `python3`). Instálalos en un **entorno virtual** dentro del repo:
```bash
cd ~/tareas
python3 -m venv .venv
.venv/bin/pip install -r backend/requirements-dev.txt
.venv/bin/python -m pytest --version
```
- `python3 -m venv .venv` crea una carpeta `.venv` con su propio Python y su
  propio `pip`. Lo que instales ahí no toca el Python del sistema.
- No hace falta Internet: `/etc/pip.conf` le dice a `pip` que use el mirror
  interno `/opt/wheels`.
- `.venv/` ya está en `.gitignore`: no se sube.

**Qué deberías ver:** `pytest 8.3.4`.
:::

:::ojo No uses `sudo pip install`
Debian protege el Python del sistema y lo rechaza con
`externally-managed-environment`. Saltárselo con `--break-system-packages`
puede romper herramientas del sistema que dependen de él. Un `.venv` por
proyecto es lo correcto.
:::

## Paso 3 · Tests contra PostgreSQL

**Objetivo:** que los tests se ejecuten de verdad, contra la base de pruebas
del servidor de CI.

**Pregúntate:** si le das la variable `DATABASE_URL`, ¿pasan?

:::pista Cómo hacerlo
```bash
cd ~/tareas/backend
export DATABASE_URL=postgresql://ci:ci@127.0.0.1:5432/tareas_test
../.venv/bin/pytest -v
```
`export` deja la variable puesta para los comandos siguientes de esta
terminal. La URL dice: PostgreSQL, usuario `ci`, contraseña `ci`, en
`127.0.0.1:5432`, base `tareas_test`.

**Qué deberías ver:** ya no se saltan… pero fallan con
`ModuleNotFoundError: No module named 'app'`. Nunca se habían ejecutado, así
que nadie lo vio. El motivo:

- El comando `pytest` añade a la ruta de búsqueda de módulos la carpeta de
  cada test (`backend/tests/`), no la carpeta donde estás. Desde
  `backend/tests/`, `import app` no encuentra `backend/app/`.
- `python -m pytest` añade además la carpeta actual (`backend/`), y ahí sí
  está `app/`.

```bash
../.venv/bin/python -m pytest -v
```
**Qué deberías ver:** `4 passed`. (También valdría añadir
`pythonpath = ["."]` en `[tool.pytest.ini_options]` de `backend/pyproject.toml`.)
:::

## Paso 4 · El linter

**Objetivo:** pasar `ruff` y arreglar lo que encuentre.

:::pista Cómo hacerlo
```bash
cd ~/tareas
.venv/bin/ruff check backend
```
**ruff** es un *linter*: lee el código sin ejecutarlo y avisa de errores y
malas prácticas.

**Qué deberías ver:** `F821 Undefined name 'tarea'` en `marcar_hecha`. El
mensaje del 404 usa `{tarea}`, una variable que no existe (la de la función
se llama `tarea_id`). Al intentar construir el mensaje, Python lanza un
`NameError` y el cliente recibe un **500** en lugar del 404. Es exactamente el
bug de producción. Corrígelo en `backend/app/main.py`:
```python
        raise HTTPException(404, f"la tarea {tarea_id} no existe")
```
y repite hasta ver `All checks passed!`.
:::

## Paso 5 · El workflow completo

**Objetivo:** lint y tests de verdad, y despliegue (con el frontend
construido) sólo si pasan y sólo desde `main`.

:::pista Cómo hacerlo
Sustituye `.github/workflows/ci.yml`:
```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: self-hosted
    env:
      DATABASE_URL: postgresql://ci:ci@127.0.0.1:5432/tareas_test
    steps:
      - uses: actions/checkout@v4
      - name: Dependencias
        run: |
          python3 -m venv .venv
          .venv/bin/pip install -r backend/requirements-dev.txt
      - name: Lint
        run: .venv/bin/ruff check backend
      - name: Tests
        run: cd backend && ../.venv/bin/python -m pytest -v

  deploy:
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Frontend
        run: |
          cd frontend
          npm ci
          npm run build
          rm -rf ../backend/static
          cp -r dist ../backend/static
      - name: Desplegar
        run: sudo /usr/local/bin/desplegar-tareas "$PWD" "${{ github.sha }}"
```

| Pieza | Qué hace |
|---|---|
| `env:` del job `test` | Define `DATABASE_URL` para todos los pasos del job: los tests dejan de saltarse. En GitHub se usaría `services: postgres`, pero eso necesita Docker; aquí el servidor de CI tiene su propia base. |
| Sin `continue-on-error` | Si un paso falla, el job falla. Es lo normal; la línea vieja lo impedía. |
| `needs: test` | `deploy` sólo empieza cuando `test` ha terminado **bien**. |
| `if: … refs/heads/main` | En un pull request o en otra rama, el job `deploy` se salta. |
| `npm ci` | Instala exactamente lo que dice `package-lock.json` (a diferencia de `npm install`, no lo modifica). Funciona sin Internet con la caché interna. |
| `npm run build` | Vite genera el frontend en `frontend/dist`; lo copiamos donde el backend lo sirve (`backend/static`). |

Cada job empieza en una copia limpia del repo: el frontend se construye en el
**mismo** job que despliega, o no llegaría al despliegue.
:::

## Paso 6 · Sube y comprueba

```bash
cd ~/tareas
git status          # .venv/, node_modules/ y dist/ no deben aparecer
git add -A
git commit -m "ci: lint, tests con PostgreSQL y despliegue sólo desde main"
git push origin main
ci-estado           # repite hasta que termine
ci-log | grep -E 'passed|skipped|All checks'
curl -s http://localhost:8080/api/salud
bash /opt/lab/check.sh
```
**Qué deberías ver:** `4 passed`, ningún `skipped`, `All checks passed!` y, en
`/api/salud`, la versión con el SHA de tu commit.

## Cómo actuar en una situación así

- Desconfía de los pipelines que nunca fallan: cuenta los tests en el log.
- `continue-on-error` y los `skip` silenciosos convierten la CI en decoración.
- Si un test necesita una dependencia (una base de datos), dásela en la CI; no
  lo saltes "porque falla".
- Reproduce la CI en local con el mismo entorno antes de empujar.

## Si te atascas

- **`ModuleNotFoundError: No module named 'app'` en el pipeline:** usa
  `python -m pytest`, no el binario `pytest`.
- **`externally-managed-environment`:** estás usando el `pip` del sistema.
  Usa `.venv/bin/pip`.
- **Verde pero `/` sigue dando 404:** el frontend no se construyó en el job
  `deploy`, o no se copió a `backend/static`.
- **`git status` enseña `.venv/` o `node_modules/`:** no los añadas. Revisa
  `.gitignore`.
