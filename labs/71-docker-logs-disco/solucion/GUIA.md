# Resolución guiada · Los logs de Docker llenan el disco

:::piensa ¿Dónde se van los logs de un contenedor?
Todo lo que un contenedor escribe por su salida estándar lo guarda Docker en
un fichero JSON en el disco del host (el *driver* `json-file`). Por defecto
ese fichero **no rota**: crece para siempre. Con el worker en `DEBUG`, ha
llenado el disco. Hay que hacer tres cosas, en este orden: recuperar espacio
**sin parar nada**, arreglar la causa en `compose.yaml` y recrear los
contenedores para que la causa arreglada se aplique.
:::

**El plan:** (1) encontrar qué ocupa, (2) vaciar el log sin borrarlo,
(3) reescribir `compose.yaml` y aplicarlo, y (4) comprobar.

## Paso 1 · ¿Qué ocupa el disco?

**Objetivo:** confirmar que son los logs y de qué contenedor.

**Pregúntate:** ¿lo que ocupa son imágenes, volúmenes o logs?

:::pista Cómo hacerlo
```bash
df -h /var/lib/docker
docker system df
sudo du -sh /var/lib/docker/containers/* | sort -h | tail -3
docker inspect -f '{{.Name}} {{.LogPath}}' $(docker ps -q)
```

| Comando | Qué enseña |
|---|---|
| `df -h` | Uso del sistema de ficheros, en unidades legibles (`-h`). |
| `docker system df` | Lo que ocupan imágenes, contenedores, volúmenes y caché. **No cuenta los logs**: por eso aquí parece que todo está bien. |
| `du -sh … \| sort -h` | Tamaño de cada carpeta de contenedor (`-s` total, `-h` legible), ordenado por tamaño. |
| `docker inspect -f '{{.LogPath}}'` | La ruta del fichero de log de cada contenedor. `$(docker ps -q)` pasa los IDs de todos los que están en marcha. |

**Qué deberías ver:** `/var/lib/docker` por encima del 85 % y una carpeta de
contenedor de cientos de MB: la del worker.
:::

## Paso 2 · Libera espacio sin parar nada

**Objetivo:** recuperar el espacio ya, sin tocar los contenedores.

**Pregúntate:** el fichero lo tiene abierto `dockerd`, que sigue escribiendo
en él. ¿Qué pasa si lo borras con `rm`?

:::pista Cómo hacerlo
Con `rm` desaparece el **nombre** del fichero, pero como `dockerd` lo tiene
abierto, sus datos siguen en disco hasta que lo cierre: no recuperas nada.
`truncate` lo vacía sin cerrarlo:
```bash
sudo truncate -s 0 "$(docker inspect -f '{{.LogPath}}' pedidos-worker-1)"
df -h /var/lib/docker
```
`truncate -s 0` fija el tamaño del fichero a 0 bytes.

**Qué deberías ver:** el uso muy por debajo del 50 %. Si quieres conservar el
final del log para la investigación, cópialo antes:
`sudo tail -c 50M <ruta> > /tmp/worker-ultimo.log`.

`sudo lsof +L1` lista ficheros **borrados** que algún proceso aún tiene
abiertos (`+L1` = con menos de 1 enlace, es decir, sin nombre). Si borraste
algo con `rm`, aparecerá ahí.
:::

## Paso 3 · Arregla la causa en `compose.yaml`

**Objetivo:** el worker en `INFO`, y una política de rotación para **los dos**
servicios, escrita en el fichero (versionada).

:::pista Cómo hacerlo
Sustituye `/srv/pedidos/compose.yaml`:
```yaml
name: pedidos

x-logging: &logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  api:
    image: python:3.12-alpine
    command: ["python", "-u", "/app/api.py"]
    volumes:
      - ./app:/app:ro
    ports:
      - "127.0.0.1:8000:8000"
    restart: unless-stopped
    logging: *logging

  worker:
    image: python:3.12-alpine
    command: ["python", "-u", "/app/worker.py"]
    environment:
      LOG_LEVEL: INFO
      BACKLOG: "1150000"
    volumes:
      - ./app:/app:ro
    restart: unless-stopped
    logging: *logging
```

| Pieza | Qué hace |
|---|---|
| `x-logging:` | Compose ignora las claves que empiezan por `x-`: sirven para guardar bloques reutilizables. |
| `&logging` | Un **ancla** de YAML: pone nombre a ese bloque. |
| `logging: *logging` | Un **alias**: "pega aquí el bloque `logging`". Así la política se escribe una vez y se aplica a los dos servicios. |
| `max-size: "10m"` | Cuando el log llega a 10 MB, Docker lo rota (empieza uno nuevo). |
| `max-file: "3"` | Guarda como mucho 3 ficheros: el máximo por contenedor es 30 MB. |
| `LOG_LEVEL: INFO` | El worker deja de volcar el detalle de cada mensaje. |

Valida y aplica:
```bash
cd /srv/pedidos
docker compose config >/dev/null && docker compose up -d
docker inspect -f '{{.Name}} {{json .HostConfig.LogConfig}}' $(docker compose ps -q)
```
- `docker compose config` interpreta el fichero (con anclas y alias
  resueltos); si hay un error de sintaxis, lo dice sin tocar nada.
- `up -d` compara la configuración nueva con la de cada contenedor y
  **recrea** los que han cambiado.

La configuración de logs se fija al **crear** el contenedor. `docker compose
restart` reinicia el mismo contenedor con su configuración vieja: no sirve.

**Qué deberías ver:** los dos contenedores con
`{"Type":"json-file","Config":{"max-file":"3","max-size":"10m"}}`.
:::

## Paso 4 · Comprueba

```bash
df -h /var/lib/docker
curl -s 127.0.0.1:8000
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **`json-file` no rota por defecto:** un contenedor hablador llena el disco.
- Un log abierto se vacía con `truncate`, nunca con `rm`.
- Para que sea el valor por defecto de todos los contenedores futuros:
  `/etc/docker/daemon.json` con
  `{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}`.
  Requiere reiniciar `dockerd` y sólo afecta a contenedores nuevos.
- `DEBUG` en producción, siempre con fecha de caducidad.

## Si te atascas

- **Borraste el log con `rm` y el disco sigue lleno:** el fichero sigue
  abierto. Al recrear el contenedor (`up -d`), Docker lo cierra y el espacio se
  libera.
- **El check dice que el contenedor no aplica la rotación:** usaste
  `restart`. Haz `docker compose up -d`.
- **`docker compose config` falla:** suele ser la sangría o un alias
  (`*logging`) sin su ancla (`&logging`).
