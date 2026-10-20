# Día 16 — Auditoría de traspaso de un stack Compose

> 30 días de DevSecOps · Docker · Exposición del runtime de contenedores

## Escenario

Te pasan el stack `handoff` (pedidos) que ya está **corriendo** en este host.
El equipo saliente dejó un `README.md` y un `compose.yaml` en `~/handoff`,
pero durante un incidente alguien aplicó un *hotfix* con otro fichero Compose
que después borró. Lo que hay en disco **ya no describe** lo que corre.

Tu trabajo: registrar la línea base **real** del stack, sacada del runtime.

> Este lab tiene su propio Docker Engine dentro del contenedor: `docker ps`
> te enseña el stack del escenario, no los contenedores de tu máquina.

## Objetivos

Crea `~/audit/handoff.txt` con este formato `clave=valor`:

```
entrypoint_servicio=<servicio que publica un puerto en el host>
entrypoint_puerto=<puerto del HOST que publica>
redes_web=<redes, separadas por comas>
redes_api=...
redes_worker=...
redes_db=...
volumen_compartido=<volumen montado por más de un servicio>
volumen_montado_en=<servicios que lo montan, separados por comas>
```

- Puedes escribir las redes/volúmenes con o sin el prefijo del proyecto
  (`frontend` o `handoff_frontend`).
- **No cambies el stack**: nada de `docker compose up`, `down` ni `restart`.
  Un `up` con el `compose.yaml` actual "deshace" el hotfix y destruye la evidencia.

## Comandos que te pueden servir

```bash
docker compose -p handoff ps
docker ps --format 'table {{.Names}}\t{{.Ports}}'
docker port <contenedor>
docker inspect <contenedor> --format '{{json .NetworkSettings.Networks}}' | jq 'keys'
docker inspect <contenedor> --format '{{json .Mounts}}' | jq
docker network ls ; docker volume ls
docker network inspect handoff_backend --format '{{range .Containers}}{{.Name}} {{end}}'
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
