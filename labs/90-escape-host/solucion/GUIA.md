# Resolución guiada · Lab 90

:::piensa Cinco puertas abiertas para leer un fichero
Un contenedor aísla porque **no** ve los procesos, la red, los dispositivos ni
los ficheros del host. Cada opción de este `compose.yaml` quita una de esas
barreras. La app sólo necesita leer `/data/msg` y escuchar en el 8080: si una
opción no sirve para eso, fuera.
:::

**El plan:** (1) ver qué tiene hoy el contenedor, (2) entender qué abre cada
opción, (3) dejar `compose.yaml` en lo mínimo y (4) comprobar.

## Paso 1 · ¿Qué tiene hoy?

:::pista Cómo hacerlo
```bash
cd ~/edge && cat compose.yaml
docker inspect edge-api-1 --format '{{.HostConfig.Privileged}} {{.HostConfig.PidMode}} {{.HostConfig.NetworkMode}}'
docker inspect edge-api-1 --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'
```
La primera plantilla saca tres campos de la configuración del contenedor; la
segunda recorre sus montajes (`range .Mounts`) e imprime origen y destino de
cada uno.

**Qué deberías ver:** `true host host`, y montajes de `/var/run/docker.sock`,
`/` → `/host` y `./data` → `/data`.
:::

## Paso 2 · ¿Qué abre cada opción?

:::pista La lista
| Opción | Qué le da al contenedor | Por qué es un escape |
|---|---|---|
| `privileged: true` | Todas las capacidades de root y acceso a todos los dispositivos del host. | Puede montar el disco del host y escribir en él. |
| `pid: host` | Ve todos los procesos del host. | Puede leer su entorno (secretos) y, con privilegios, entrar en ellos. |
| `network_mode: host` | Usa la red del host directamente. | Alcanza servicios que escuchan sólo en `127.0.0.1` del host. |
| `/var/run/docker.sock` | Control total del motor Docker. | Puede lanzar un contenedor nuevo con el `/` del host montado: es root del host. |
| `/:/host` | El sistema de ficheros entero del host. | Lee `/etc/shadow`, claves SSH… y escribe si quiere. |

Ninguna hace falta para leer `/data/msg` y servir el 8080.
:::

## Paso 3 · `compose.yaml` mínimo

**Objetivo:** dejar sólo lo que la app usa.

:::pista Cómo hacerlo
```yaml
name: edge

services:
  api:
    image: shop/edge:1.0
    build: ./api
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data:ro
    restart: unless-stopped
```
- Sin `network_mode: host`, el contenedor tiene su propia red; `ports` publica
  el 8080 en el host para que `curl localhost:8080` siga funcionando.
- `./data:/data:ro`: el `:ro` (sólo lectura) basta, porque la app sólo lee.

```bash
docker compose up -d
```
`up -d` recrea el contenedor con la configuración nueva. (Un `docker update`
no serviría: no puede cambiar montajes ni modos, y el cambio no quedaría
escrito en el fichero.)
:::

## Paso 4 · Comprueba

```bash
docker inspect edge-api-1 --format '{{.HostConfig.Privileged}} {{.HostConfig.PidMode}} {{.HostConfig.NetworkMode}}'
curl -s localhost:8080
bash /opt/lab/check.sh
```
**Qué deberías ver:** `false` y dos campos vacíos o `edge_default` (la red del
proyecto), y `edge-ok`.

## Cómo actuar en una situación así

- Revisa en cada code review: `privileged`, `pid: host`, `network_mode: host`,
  `docker.sock` y montajes de rutas del sistema (`/`, `/etc`, `/proc`).
- Si de verdad necesitas una capacidad, añade **esa** (`cap_add`), nunca
  `privileged`. Lab 89.
- Herramientas como `trivy config` o `kube-score` detectan estos patrones
  automáticamente en el pipeline.

## Si te atascas

- **`curl` no responde tras el cambio:** al quitar `network_mode: host` hace
  falta `ports: ["8080:8080"]`.
- **`edge-ok` no sale:** el montaje de `./data` tiene que llegar a `/data`, que
  es la ruta que lee la app.
