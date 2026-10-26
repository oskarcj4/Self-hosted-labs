# Resolución guiada · Los logs de Docker llenan el disco

:::piensa Antes de tocar nada
Es producción: no borres contenedores ni volúmenes "a ver". El driver
json-file **no rota** por defecto, y alguien dejó el worker en `DEBUG`. Tres
cosas: recuperar espacio **sin parar nada** (truncate, no rm), arreglar la causa
(LOG_LEVEL + política de logs en el compose) y recrear para que se aplique.
:::

## Paso 1 · ¿Qué ocupa?

**Pregúntate:** ¿son imágenes/volúmenes, o los logs? `docker system df` **no**
cuenta los logs.

:::pista Cómo verlo
```bash
df -h /var/lib/docker
docker system df                                   # imágenes/volúmenes: poco
sudo du -sh /var/lib/docker/containers/* | sort -h | tail -3
docker inspect -f '{{.Name}} {{.LogPath}}' $(docker ps -q)
# /pedidos-worker-1 .../<id>-json.log  ~250 MB
```
:::

## Paso 2 · Libera espacio sin parar nada

**Pregúntate:** ¿`rm` o `truncate`? dockerd tiene el fichero abierto.

:::pista Cómo hacerlo
```bash
sudo truncate -s 0 "$(docker inspect -f '{{.LogPath}}' pedidos-worker-1)"
df -h /var/lib/docker
```
**No** `rm`: el fichero sigue abierto por dockerd, el espacio no se libera
(`lsof +L1`, como el lab 55). `truncate` lo vacía sin tocar el descriptor. Si
quieres el historial, copia antes `tail -c 50M ... > /otra/ruta`.
:::

## Paso 3 · Arregla la causa en el compose

**Pregúntate:** ¿dónde pongo `LOG_LEVEL=INFO` y la rotación para **los dos**
servicios?

:::pista `compose.yaml`
```yaml
name: pedidos
x-logging: &logging
  driver: json-file
  options: { max-size: "10m", max-file: "3" }
services:
  api:
    # ... ports "127.0.0.1:8000:8000"
    logging: *logging
  worker:
    environment:
      LOG_LEVEL: INFO
    logging: *logging
```
```bash
cd /srv/pedidos
docker compose config >/dev/null && docker compose up -d     # RECREA, no restart
docker inspect -f '{{.Name}} {{json .HostConfig.LogConfig}}' $(docker compose ps -q)
```
La config de logs se fija al **crear** el contenedor: `restart` no la aplica,
`up -d` detecta el cambio y recrea.
:::

## Paso 4 · Valor por defecto del daemon (opcional, para el futuro)

```json
// /etc/docker/daemon.json
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
```
Requiere reiniciar dockerd y sólo afecta a contenedores nuevos; planifícalo.

## Verifica

```bash
df -h /var/lib/docker            # <50%
curl -s 127.0.0.1:8000
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **json-file no rota** por defecto: un contenedor hablador llena el disco.
- **Log abierto se libera con `truncate`, nunca `rm`.**
- **La config de logs se aplica al crear** el contenedor: recrea tras cambiarla.
- **DEBUG en producción con fecha de caducidad.**
- Alternativas: driver `local` (rota y comprime), journald, colector central
  (lab 75).

## Si te atascas

- Borraste el log con `rm` y el disco sigue lleno → fichero abierto; reinicia el
  contenedor o usa `truncate` sobre el nuevo.
- `restart` no aplicó la rotación → usa `up -d` (recrea).
