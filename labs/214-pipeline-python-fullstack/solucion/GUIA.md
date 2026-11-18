# Resolución guiada · Lab 214

:::piensa ¿Qué significa un pipeline en verde?
Sólo lo que comprueba. Un verde con 0 tests ejecutados no dice nada. Antes de
tocar nada, abre el log de la última ejecución y cuenta: ¿cuántos *passed*?
¿cuántos *skipped*? ¿Hay algún paso que no pueda fallar?
:::

## Paso 1 · Lee el verde

:::pista Cómo hacerlo
```bash
ci-log | grep -E 'passed|skipped|continue'
```
`4 skipped`: el `skipif` de los tests mira `DATABASE_URL`, y el workflow no la define.
:::

## Paso 2 · Tests contra PostgreSQL

:::pista Cómo hacerlo
En GitHub usarías `services: postgres:`; eso necesita Docker. Aquí, la base de CI:
```yaml
jobs:
  test:
    runs-on: self-hosted
    env:
      DATABASE_URL: postgresql://ci:ci@127.0.0.1:5432/tareas_test
```
Y quita `continue-on-error`.
:::

:::piensa Ahora fallan con ModuleNotFoundError: No module named 'app'
Nunca se habían ejecutado, así que nadie lo vio. El binario `pytest` no mete
el directorio actual en `sys.path`; `python -m pytest` sí. También vale
`pythonpath = ["."]` en `[tool.pytest.ini_options]`.
:::

## Paso 3 · Lint

:::pista Cómo hacerlo
Añade `.venv/bin/ruff check backend`. Encontrará un `F821 Undefined name` en
`marcar_hecha`: el 404 hace referencia a una variable que no existe, así que
en vez de un 404 sale un `NameError` y un 500. Corrígelo.
:::

## Paso 4 · Frontend y despliegue

:::pista Cómo hacerlo
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

## Cómo actuar en una situación así

- Desconfía de los pipelines que nunca fallan: cuenta los tests en el log.
- `continue-on-error` y los `skip` silenciosos convierten la CI en decoración.
- Si un test necesita una dependencia (una base de datos), dásela en la CI;
  no lo saltes "porque falla".
