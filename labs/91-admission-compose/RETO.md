# Admission: política de Compose

> Pipeline / runtime · admission · policy as code · red team

## Escenario

En `~/shipyard` el *deploy* es `./deploy.sh`: un `docker compose up` a pelo.
El stack actual corre `privileged` y con `docker.sock` montado.

Plataforma ya escribió `admit.sh`: un `grep` que rechaza `fixtures/bad.yaml`
y por eso "funciona". Red team te ha dejado dos manifiestos en `fixtures/`
(`bypass-*.yaml`) que el `grep` deja pasar, y avisa: **tiene más**.

Un controlador de admisión no lee texto: evalúa lo que Docker **va a
ejecutar**. Interpolación `${VAR:-x}`, sintaxis larga de volúmenes, `extends`,
comillas… todo eso cambia el texto sin cambiar el contenedor.

## Política que tiene que cumplir admit.sh

Para **cada** servicio, DENY si:

- `privileged` es verdadero.
- `pid`, `ipc`, `network_mode` o `userns_mode` es `host`.
- Monta en bind `/`, algo bajo `/var/run`, `/run`, `/proc`, `/sys`, `/etc`,
  `/var/lib/docker`, o cualquier ruta que acabe en `docker.sock`.
- `cap_add` incluye `ALL`, `SYS_ADMIN`, `SYS_MODULE` o `SYS_PTRACE`.
- `security_opt` contiene `unconfined`.
- **Fail-closed:** si el manifiesto no se puede evaluar (YAML roto), DENY.

Y no puede dar falsos positivos: un comentario o una variable de entorno que
*mencione* `docker.sock` no es un montaje.

## Objetivos

1. `admit.sh` aplica la política de arriba y resiste el corpus oculto de red
   team (bypasses + manifiestos legítimos que deben pasar).
2. `./deploy.sh` no levanta nada si `admit.sh` rechaza el manifiesto.
3. El servicio `api` corre sin privileged ni docker.sock y `curl :8080` → `api ok`.

## Comandos que te pueden servir

```bash
cd ~/shipyard
./admit.sh fixtures/bypass-interp.yaml ; echo exit:$?
docker compose -f fixtures/bypass-interp.yaml config            # lo que Docker ve
docker compose -f fixtures/bypass-longform.yaml config --format json | jq '.services'
./deploy.sh && curl -s localhost:8080
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
