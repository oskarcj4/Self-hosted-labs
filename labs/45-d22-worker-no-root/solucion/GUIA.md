# Resolución guiada · Día 22

:::piensa Antes de tocar nada
Root dentro del contenedor es el mismo UID 0 que root en el host (salvo configuraciones especiales). Con un bind mount, ese root escribe en el host como root. Quitarle root al worker tiene dos partes: **decirle con qué usuario correr** y **darle a ese usuario lo que necesita** (las carpetas de trabajo).
:::

## Paso 1 · Comprueba

:::pista Cómo comprobarlo
```bash
cd ~/media
cat compose.yaml thumbnailer/Dockerfile
docker compose exec thumbnailer id
ls -ln jobs jobs/*
```
`ls -ln` muestra UIDs numéricos: en un bind mount, **sólo cuentan los números**.
:::

## Paso 2 · Elige un UID fijo

**Pregúntate:** ¿por qué un número fijo (p.ej. `10001`) y no un nombre? Porque el host no conoce los nombres del contenedor, sólo los números. Un UID fijo y alto evita coincidir con usuarios reales del host.

## Paso 3 · Fíjalo en la imagen

:::pista Cómo hacerlo
En `thumbnailer/Dockerfile`, antes del `CMD`:
```dockerfile
RUN addgroup -S -g 10001 thumb && adduser -S -D -H -u 10001 -G thumb thumb
USER 10001:10001
```
(Alternativa: `user: "10001:10001"` en el servicio de `compose.yaml`.)
:::

## Paso 4 · Dale las carpetas, no el mundo

**Pregúntate:** el worker mueve ficheros de `in/` a `done/` y escribe en `out/`. ¿Qué necesita en cada carpeta? Escritura en las tres (mover un fichero es escribir en la carpeta de origen y de destino).

:::pista Cómo hacerlo
```bash
sudo chown -R 10001:10001 jobs
sudo chmod 0750 jobs jobs/*
```
Nada de `777`: sólo el dueño correcto.
:::

## Paso 5 · Reconstruye y prueba el flujo completo

```bash
docker compose up -d --build
docker compose exec thumbnailer id
echo hola | sudo tee jobs/in/prueba.jpg >/dev/null
sleep 3; sudo ls jobs/out jobs/done
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **`USER` en la imagen + UID numérico fijo + datos propiedad de ese UID.**
- **`chmod 777` para que funcione** sólo cambia un problema por otro.
- Si falla, `docker compose logs thumbnailer` te dice qué ruta no puede tocar.

## Si te atascas

- `id` sigue diciendo root: te faltó `--build` y corre la imagen vieja.
- `PermissionError` en los logs: revisa `ls -ln jobs jobs/*` y que todas sean del UID elegido.
