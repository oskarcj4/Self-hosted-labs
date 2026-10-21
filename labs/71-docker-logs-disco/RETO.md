# Los logs de Docker llenan el disco

> Operaciones · Docker · json-file · rotación de logs · Compose

## Escenario

El despliegue de esta mañana en `docker-02` ha fallado con `no space left on
device`. El jueves alguien puso el worker en `LOG_LEVEL=DEBUG` para depurar
una caída, y nadie lo volvió a cambiar. Lee `~/ticket/INC-7111.txt`.

El stack está en `/srv/pedidos` (Docker Compose). Es producción: no borres
contenedores ni volúmenes "a ver si se arregla".

## Objetivos

1. Recupera el espacio: `/var/lib/docker` por debajo del 50%, y que nada
   borrado siga ocupando disco.
2. El worker vuelve a `LOG_LEVEL=INFO`.
3. La política de logs (json-file, `max-size` ≤ 10m, `max-file` ≤ 3), escrita
   en `compose.yaml` para **los dos** servicios...
4. ...y aplicada de verdad en los contenedores que están en marcha.
5. La API sigue respondiendo en `127.0.0.1:8000`.

## Comandos que te pueden servir

```bash
df -h /var/lib/docker
docker system df
sudo du -sh /var/lib/docker/containers/* | sort -h
docker inspect -f '{{.Name}} {{.LogPath}}' $(docker ps -q)
docker inspect -f '{{json .HostConfig.LogConfig}}' <contenedor>
sudo truncate -s 0 <fichero>
sudo lsof +L1                         # ficheros borrados que siguen abiertos
cd /srv/pedidos && docker compose config && docker compose up -d
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
