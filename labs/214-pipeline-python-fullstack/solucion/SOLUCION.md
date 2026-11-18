# Solución — Pipeline full stack: Python

## Qué fallaba y cómo se arregla

| Problema | Arreglo |
|----------|---------|
| Tests *skipped* sin `DATABASE_URL` | `env: DATABASE_URL: postgresql://ci:ci@127.0.0.1:5432/tareas_test` en el job de tests |
| `continue-on-error: true` | quitarlo: si los tests fallan, el pipeline falla |
| `ModuleNotFoundError: app` al correr por fin los tests | `python -m pytest` (o `pythonpath = ["."]` en pyproject) |
| Sin lint | paso `ruff check backend` |
| `NameError` en el 404 (`{tarea}`) | `{tarea_id}`; ruff lo marca como F821 |
| Frontend sin construir | `npm ci && npm run build` y copiar `dist` a `backend/static`, en el job que despliega |
| Despliegue desde cualquier rama, aunque fallen los tests | job `deploy` con `needs: test` e `if: github.ref == 'refs/heads/main'` (o `on.push.branches: [main]`) |

El workflow completo está en `solve.sh`.

## Por qué así

- **`npm ci`**, no `npm install`: instala exactamente lo del `package-lock.json`
  y falla si no cuadra con `package.json`. Reproducible.
- **Lint antes que tests**: es más rápido, y encuentra errores en caminos que
  los tests no cubren (como el 404 de este lab).
- **Dos jobs**: el de tests puede correr también en *pull requests*; el de
  despliegue sólo en `main` y sólo tras los tests.
- **Una base de CI propia**: separada de producción, con un usuario sin más
  permisos que su base, y vaciada al inicio de cada test (`TRUNCATE`).

## Más allá del lab

- Con Docker en el runner: `services: postgres:16` y una base nueva por ejecución.
- Cobertura mínima (`pytest --cov --cov-fail-under=80`).
- Caché de `pip` y de `npm` con `actions/cache` (lab 187).
- Construir el frontend una vez y pasarlo como artefacto entre jobs.
