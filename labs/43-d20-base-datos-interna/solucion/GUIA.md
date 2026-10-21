# Resolución guiada · Día 20

:::piensa Antes de tocar nada
Una base de datos sólo necesita hablar con **su aplicación**, y ambas están en la misma red interna del proyecto. Publicar su puerto en el host fue un atajo temporal para una migración. La pregunta para cerrar: ¿hay alguien fuera del proyecto que **todavía** necesite llegar? Si no, se retira.
:::

## Paso 1 · Demuestra el riesgo

**Pregúntate:** ¿puede alguien desde la red hablar con la base de datos sin pasar por la API?

:::pista Cómo comprobarlo
```bash
cd ~/inventory
docker compose ps
exec 3<>/dev/tcp/$(hostname -i)/5432; echo DUMP >&3; timeout 1 cat <&3
```
:::

## Paso 2 · ¿Cómo llega la API a la base de datos?

**Pregúntate:** ¿la API usa el puerto publicado o el nombre del servicio?

:::pista Cómo comprobarlo
```bash
cat compose.yaml
curl -s http://$(hostname -i):8000/
```
La API usa `db:5432` por la red del proyecto. El puerto publicado no le hace falta.
:::

## Paso 3 · Retira la publicación

:::pista Cómo hacerlo
Borra el bloque `ports:` entero del servicio `db` en `compose.yaml` y aplica:
```bash
docker compose up -d
```
:::

## Paso 4 · Verifica

```bash
docker compose ps
timeout 2 bash -c "exec 3<>/dev/tcp/$(hostname -i)/5432" && echo ABIERTO || echo cerrado
curl -s http://$(hostname -i):8000/
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Las bases de datos no se publican**: viven detrás de la app.
- **Lo temporal lleva fecha de retirada** y un responsable.
- **Acceso puntual de administración**: `docker compose exec db ...`, túnel SSH o `127.0.0.1:5432:5432` sólo mientras dure la tarea.

## Si te atascas

- La API deja de ver la base de datos: no cambies redes ni nombres; sólo quita `ports:` de `db`.
