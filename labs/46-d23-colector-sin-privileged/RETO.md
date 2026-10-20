# Día 23 — Quitar privileged a un colector

> 30 días de DevSecOps · Docker · Montajes, usuarios y privilegios

## Escenario

`collector` (stack `logs`, en `~/logs`) lee `logs/app.log` y escribe un
resumen en `out/summary.txt`. Corre con **`privileged: true`**: acceso a todos
los dispositivos del host, todas las capacidades y sin perfiles de seguridad.
Escapar de un contenedor así es trivial.

Alguien lo copió de un ejemplo porque el arranque ejecuta un `sysctl`.

## Objetivos

1. Quita `privileged` del colector (y no lo sustituyas por `cap_add: [ALL]`,
   `SYS_ADMIN` o dispositivos del host).
2. El colector debe arrancar y quedarse estable.
3. Debe seguir resumiendo: una nueva línea `ERROR` en `logs/app.log` se refleja
   en `out/summary.txt` en pocos segundos.
4. El cambio debe estar en `compose.yaml`.

> Pregunta: ¿necesita un colector de logs ese `sysctl`? Y si lo necesitara,
> ¿hay forma de fijar un sysctl **del espacio de red del contenedor** sin privileged?

## Comandos que te pueden servir

```bash
cd ~/logs && cat compose.yaml collector/collector.py
docker compose up -d ; docker compose ps -a
docker compose logs collector --tail 10
cat out/summary.txt
echo "$(date +%FT%T) app ERROR prueba" >> logs/app.log ; sleep 4 ; cat out/summary.txt
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
