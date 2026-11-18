#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/tareas
git pull -q

# 1. El bug que ruff encuentra (F821: nombre no definido en la ruta del 404).
sed -i 's/la tarea {tarea} no existe/la tarea {tarea_id} no existe/' backend/app/main.py

# 2. Workflow: lint + tests con PostgreSQL, y despliegue (con frontend) sólo si pasan y sólo desde main.
cat > .github/workflows/ci.yml <<'YML'
name: ci
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: self-hosted
    env:
      # Sin Docker no hay "services: postgres": base de pruebas propia del servidor de CI.
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
        # "python -m pytest" añade backend/ al sys.path; el binario pytest, no
        # (los tests nunca habían corrido, así que nadie lo había visto).
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
YML
git add -A
git commit -qm "ci: lint, tests con PostgreSQL, frontend y despliegue sólo desde main"
git push -q origin main

SHA=$(git rev-parse HEAD)
echo "Esperando al pipeline de ${SHA:0:8}..."
for _ in $(seq 1 240); do
  curl -fs http://127.0.0.1:8080/api/salud | grep -q "$SHA" && break
  sleep 2
done
ci-estado
echo "solve.sh completado."
