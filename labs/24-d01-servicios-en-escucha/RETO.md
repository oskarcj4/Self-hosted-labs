# Día 01 — Auditar servicios en escucha

> 30 días de DevSecOps · Linux · Exposición e higiene web

## Escenario

Heredas `edge-01` de otro equipo. Te pasaron una tabla de servicios en
`~/handoff/servicios.md`, pero nadie garantiza que esté al día. Antes de
cambiar nada quieres una **línea base real**: qué está escuchando *ahora
mismo*, en qué interfaz y qué proceso lo hace.

La regla de oro de una auditoría: **el estado en tiempo de ejecución manda;
la documentación sólo es una pista.**

## Objetivos

1. Lista todos los puertos **TCP en escucha** del host. Ignora dos que son
   del propio laboratorio: el `7681` (terminal web) y el que escucha en
   `127.0.0.11` (DNS interno de Docker).
2. Clasifica cada uno como:
   - `publico`: escucha en todas las interfaces (`0.0.0.0`, `*`, `[::]`) o en una IP no-loopback.
   - `local`: sólo en loopback (`127.0.0.1`, `[::1]`).
3. Anota el **proceso** que tiene el socket (tal como lo muestra `ss -tlnp`).
4. Guarda el inventario en `~/audit/listeners.csv` con este formato:

```
puerto,exposicion,proceso
80,publico,nginx
...
```

5. **No pares ni cambies ningún servicio.** Sólo observas.

## Comandos que te pueden servir

```bash
sudo ss -tlnp                 # TCP en escucha + proceso dueño
sudo ss -tlnp '( sport = :8873 )'
sudo lsof -iTCP -sTCP:LISTEN -P -n
systemctl list-units --type=service --state=running
cat ~/handoff/servicios.md    # compárala con lo que ves
```

> Sin `sudo`, `ss` no puede enseñarte el proceso de sockets ajenos.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
