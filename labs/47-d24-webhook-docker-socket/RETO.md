# Día 24 — Webhook sin socket de Docker

> 30 días de DevSecOps · Docker · Montajes, usuarios y privilegios

## Escenario

`webhook` (stack `deployhook`, en `~/deployhook`) recibe avisos de despliegue
desde internet en el puerto `8090` y los apunta en `events/events.log`.
Alguien le montó `/var/run/docker.sock` "para poder reiniciar cosas en el
futuro". Ese futuro nunca llegó, pero el riesgo sí:

```bash
curl -s localhost:8090/debug/containers
```

Quien controle el socket de Docker controla el host: puede lanzar un
contenedor privilegiado que monte `/` y hacer lo que quiera.

## Objetivos

1. El webhook no debe montar `docker.sock` (ni tener otra vía al daemon, como `DOCKER_HOST`).
2. `/debug/containers` ya no debe poder listar contenedores.
3. `POST /hook` debe seguir registrando eventos en `events/events.log`.
4. El cambio debe estar en `compose.yaml`.

## Comandos que te pueden servir

```bash
cd ~/deployhook && cat compose.yaml
docker inspect deployhook-webhook-1 --format '{{json .Mounts}}' | jq
docker compose exec webhook ls -l /var/run/docker.sock
curl -s -X POST -d '{"repo":"prueba"}' localhost:8090/hook ; tail -1 events/events.log
docker compose up -d
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
