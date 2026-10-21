# Solución — Los logs de Docker llenan el disco

## 1. ¿Qué ocupa?

```bash
df -h /var/lib/docker                      # 9x% / 100%
docker system df                           # imágenes y volúmenes: poco
sudo du -sh /var/lib/docker/containers/* | sort -h | tail -3
docker inspect -f '{{.Name}} {{.LogPath}}' $(docker ps -q)
# /pedidos-worker-1  /var/lib/docker/containers/<id>/<id>-json.log   <- ~250 MB
```

`docker system df` no cuenta los logs: hay que mirar `containers/`.

## 2. Liberar espacio sin parar nada

```bash
sudo truncate -s 0 "$(docker inspect -f '{{.LogPath}}' pedidos-worker-1)"
df -h /var/lib/docker
```

**No** uses `rm`: dockerd tiene el fichero abierto y seguiría escribiendo en
un fichero borrado. El espacio no se libera (`lsof +L1` lo enseña, igual que
en el lab 55). `truncate` vacía el fichero sin cambiar el descriptor.

Ten en cuenta que esto borra el historial de logs. Si lo necesitas, copia
antes la parte final (`tail -c 50M ... > /otra/ruta`).

## 3. Arreglar la causa en el compose

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

```bash
cd /srv/pedidos
docker compose config >/dev/null && docker compose up -d     # recrea api y worker
docker inspect -f '{{.Name}} {{json .HostConfig.LogConfig}}' $(docker compose ps -q)
```

La configuración de logs se fija al **crear** el contenedor. `docker compose
restart` no la aplica. `up -d` detecta el cambio y recrea el contenedor.

## 4. Además, el valor por defecto del daemon

Para que cualquier contenedor futuro tenga rotación aunque se olvide en el
compose, ponlo en `/etc/docker/daemon.json`:

```json
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
```

Esto necesita reiniciar dockerd, y sólo afecta a los contenedores nuevos. En
producción, planifícalo.

## Lecciones

- El driver json-file **no rota** por defecto: un contenedor hablador llena
  el disco tarde o temprano.
- Para liberar un log abierto: `truncate`, nunca `rm`.
- La config de logs se aplica al crear el contenedor: después de cambiarla,
  hay que recrear.
- DEBUG en producción, siempre con fecha de caducidad (y un recordatorio).
- Alternativas: el driver `local` (rota y comprime por defecto), o enviar los
  logs a journald o a un colector central (lab 75).
