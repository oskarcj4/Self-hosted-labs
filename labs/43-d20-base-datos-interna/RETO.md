# Día 20 — Mantener interna una base de datos

> 30 días de DevSecOps · Docker · Exposición del runtime de contenedores

## Escenario

El stack `inventory` (en `~/inventory`) tiene una API y una base de datos.
Durante una migración alguien publicó el puerto `5432` de la base de datos en
el host "para conectar con el cliente SQL". La migración terminó hace meses.

Hoy cualquiera que llegue al host puede hablar con la base de datos:

```bash
exec 3<>/dev/tcp/$(hostname -i)/5432; echo DUMP >&3; timeout 1 cat <&3
```

## Objetivos

1. El servicio `db` no debe publicar **ningún** puerto en el host.
2. Desde el host, `:5432` ya no responde.
3. La API (`:8000`) sigue funcionando y llegando a la base de datos (`db: PONG`).
4. El cambio debe estar en `compose.yaml`.

## Comandos que te pueden servir

```bash
cd ~/inventory && cat compose.yaml
docker compose ps
curl -s http://$(hostname -i):8000/
docker compose up -d
```

> Si algún día hace falta acceso puntual: `docker compose exec db ...` o un
> puerto ligado a `127.0.0.1` durante la tarea, y retirarlo después.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
