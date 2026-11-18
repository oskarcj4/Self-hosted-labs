# Tu propio GitHub Actions

> DevOps · CI/CD · Gitea Actions · act_runner · self-hosted · secretos

## Escenario

La empresa se va de GitHub a una forja propia: **Gitea**, que entiende la
misma sintaxis de **GitHub Actions** (`.github/workflows/*.yml`, `uses:`,
`secrets.*`). El servidor quedó a medio montar y nadie ha conseguido que
un solo workflow arranque:

- Actions está **apagado** en Gitea.
- El servidor **no tiene internet**: `uses: actions/checkout@v4` intenta
  bajarse de github.com. Ya hay un espejo interno (org `actions` en la forja).
- El runner (`act_runner`) está instalado pero **sin registrar**, y aquí
  **no hay Docker**: tiene que ejecutar en modo host.
- El workflow copiado de GitHub corre en `ubuntu-latest`, despliega desde
  **cualquier rama** y lleva el **token de despliegue en claro** (que encima
  ya está revocado; el bueno está en `/etc/deployer/token`).

Forja: <http://localhost:4213> (`analista` / `analista123`).
Producción: <http://localhost:8213> (dentro del servidor, `http://localhost:8080`).

## Objetivos

1. Gitea con Actions activado y acciones del espejo interno, sin internet.
2. El repo `analista/web` con Actions habilitado.
3. `act_runner` registrado, como servicio systemd y con un usuario propio (no root).
4. El job de despliegue corre en ese runner (su `runs-on:` casa con una etiqueta del runner).
5. Sólo se despliega desde `main`.
6. El token sale de un **secreto** del repo; en el repo no queda ningún token.
7. Producción sirve el último commit de `main`, desplegado por el pipeline.

## Pistas

```bash
cat ~/TAREA.txt; cat /etc/gitea/app.ini
act_runner --help; act_runner generate-config | less
sudo -u git gitea --config /etc/gitea/app.ini actions generate-runner-token
ci-estado; ci-log            # ejecuciones y logs del repo (o en la web de la forja)
journalctl -u act_runner -f
```

Lee lo que imprime `act_runner register`: no todos los parámetros se usan
cuando hay fichero de configuración.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
