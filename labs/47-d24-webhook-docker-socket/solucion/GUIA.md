# Resolución guiada · Día 24

:::piensa Antes de tocar nada
El socket de Docker es la API del daemon, y el daemon corre como root. Quien puede hablar con él puede pedirle "lanza un contenedor privilegiado con `/` del host montado". Por eso **montar `docker.sock` = dar root del host**. En un servicio que recibe peticiones de internet, es lo peor que se puede montar.
:::

## Paso 1 · Mide el riesgo

**Pregúntate:** ¿qué puede hacer hoy alguien que llegue al webhook?

:::pista Cómo comprobarlo
```bash
cd ~/deployhook
cat compose.yaml
curl -s localhost:8090/debug/containers | head
docker inspect deployhook-webhook-1 --format '{{json .Mounts}}'
```
Si un endpoint público lista los contenedores del host, el socket está al alcance de cualquiera.
:::

## Paso 2 · ¿Lo usa para su función?

**Pregúntate:** el webhook registra eventos en un fichero. ¿Necesita Docker para eso?

:::pista Cómo comprobarlo
```bash
ls webhook/
grep -n 'sock\|docker' webhook/*.py
```
El socket sólo alimenta un endpoint de diagnóstico. La función principal no lo usa.
:::

## Paso 3 · Quita el montaje (y cualquier otra vía)

**Pregúntate:** ¿hay otra forma de llegar al daemon? Revisa también variables como `DOCKER_HOST`.

:::pista Cómo hacerlo
En `compose.yaml`, deja en `volumes:` sólo `./events:/events` y elimina cualquier `DOCKER_HOST` del `environment:`.
```bash
docker compose up -d
```
:::

:::ojo `:ro` no protege
Montar el socket con `:ro` sólo impide borrar el fichero. La API sigue completa: se puede seguir creando contenedores.
:::

## Paso 4 · Verifica

```bash
docker compose exec webhook ls -l /var/run/docker.sock || echo "sin socket"
curl -s localhost:8090/debug/containers
curl -s -X POST -d '{"repo":"prueba"}' localhost:8090/hook; tail -1 events/events.log
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Busca `docker.sock` en todos los YAML**: es de los hallazgos más graves en contenedores.
- **Si hace falta automatizar Docker**: un proxy del socket que sólo permita las llamadas necesarias, Docker rootless, o que lo haga el pipeline de CI.
- **"Por si en el futuro…"** no es un motivo para dar privilegios hoy.

## Si te atascas

- El endpoint sigue listando: ¿hiciste `docker compose up -d`? Comprueba con `docker inspect` que el montaje desapareció.
