# Pipeline full stack: Python

> DevOps · CI/CD · Gitea Actions · FastAPI · Vite · PostgreSQL · pytest · ruff

## Escenario

La app de tareas del equipo (backend **FastAPI**, frontend **Vite**, base de
datos **PostgreSQL**) tiene un pipeline que **siempre sale en verde**.
Demasiado verde:

- los tests **no se ejecutan**: sin `DATABASE_URL` se marcan como *skipped*,
  y por si acaso el paso lleva `continue-on-error: true`;
- nadie pasa un linter, y en producción hay un **500** donde debería haber un 404;
- el frontend **no se construye**: `http://localhost:8080/` devuelve 404;
- despliega desde **cualquier rama**.

La forja y el runner ya funcionan (es el servidor del lab 213, terminado).
Aquí no hay Docker: `services: postgres` de GitHub no sirve, pero el servidor
de CI tiene su propia base de pruebas.

Forja: <http://localhost:4214> (`analista` / `analista123`) · App: <http://localhost:8214>

## Objetivos

1. Pipeline de `main` en verde.
2. Los tests corren **de verdad** contra PostgreSQL (ninguno saltado).
3. `ruff` en el pipeline, y en verde.
4. Sólo se despliega si los tests pasan (sin `continue-on-error`).
5. Sólo se despliega desde `main`.
6. Producción corre el último commit de `main`, con el frontend construido por Vite.
7. Marcar como hecha una tarea que no existe devuelve **404**.

## Pistas

```bash
cat ~/TAREA.txt
ci-estado; ci-log            # ¿cuántos tests "passed"? ¿cuántos "skipped"?
cd ~/tareas && cat .github/workflows/ci.yml
psql postgresql://ci:ci@127.0.0.1:5432/tareas_test -c 'select 1'
```

### Probar en tu terminal antes de empujar

En la terminal **no hay** `pytest` ni `ruff` instalados, ni comando `python`
(sólo `python3`): `python -m pytest` falla tal cual. Crea un entorno virtual
en el repo, igual que hace el pipeline. Funciona sin internet (`pip` usa el
mirror interno `/opt/wheels`):

```bash
cd ~/tareas
python3 -m venv .venv
.venv/bin/pip install -r backend/requirements-dev.txt
cd backend
DATABASE_URL=postgresql://ci:ci@127.0.0.1:5432/tareas_test ../.venv/bin/pytest -v
../.venv/bin/ruff check .
```

`.venv/` está en `.gitignore`: no se sube. No uses `sudo pip install`.

Cuando por fin corran los tests, puede que fallen por algo que nunca se vio
porque nunca se ejecutaron. Lee el error.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
