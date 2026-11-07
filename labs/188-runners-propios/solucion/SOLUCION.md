# Solución — Runner de CI propio

## Riesgos y arreglos

| Riesgo | Arreglo |
|--------|---------|
| jobs como root | `User=ci-runner` (usuario de sistema, sin shell) |
| token en el entorno del job | `heredar_entorno = no` |
| token legible en la unidad | `EnvironmentFile=/etc/runner/token.env` (0600) |
| restos entre jobs | `espacio_efimero = si` |
| leer `/home`, escribir en `/tmp` | `ProtectHome=yes`, `PrivateTmp=yes` |
| tocar el sistema | `ProtectSystem=strict` + `ReadWritePaths=/srv/ci`, `NoNewPrivileges=yes` |
| jobs eternos | `timeout = 60` (mata el grupo de procesos) |
| agotar recursos | `MemoryMax`, `TasksMax`, `CPUQuota` |
| cualquier job | `etiquetas = linux, x64` |

La unidad y la configuración completas están en `solve.sh`.

## Por qué todo esto, y no sólo "no root"

Un usuario sin privilegios sigue pudiendo leer lo que es legible por todos
(`/home/*/notas.txt`, la unidad con el token) y dejar ficheros en `/tmp`
para otros procesos. El sandbox de systemd quita esa superficie sin cambiar
el código del runner.

## Más allá del lab

- Runners efímeros: actions-runner-controller en Kubernetes, o una VM por job (Firecracker).
- Grupos de runners: los runners que despliegan a producción sólo aceptan jobs de `main`.
- Sin `docker.sock` en el runner: es root en el host. Usa builds sin daemon (BuildKit rootless, kaniko).
