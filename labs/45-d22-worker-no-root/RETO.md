# Día 22 — Worker sin root

> 30 días de DevSecOps · Docker · Montajes, usuarios y privilegios

## Escenario

`thumbnailer` (stack `media`, en `~/media`) procesa imágenes que suben los
usuarios: justo el tipo de código que conviene aislar. Su `Dockerfile` no
declara `USER`, así que corre como **root** dentro del contenedor (y con un
bind mount del host, ese root escribe en el host como root).

## Objetivos

1. El worker debe correr con un usuario **sin privilegios** (uid ≠ 0).
2. El usuario debe quedar fijado en la imagen (`USER`) o en `compose.yaml`
   (`user:`), no en un `docker run` manual.
3. El worker debe seguir procesando trabajos: un fichero en `jobs/in/`
   acaba como `jobs/out/<nombre>.thumb` y el original en `jobs/done/`.
4. No arregles los permisos con `chmod 777`.

## Comandos que te pueden servir

```bash
cd ~/media && cat compose.yaml thumbnailer/Dockerfile
docker compose exec thumbnailer id
ls -ln jobs/ jobs/*
docker compose logs thumbnailer --tail 20
docker compose up -d --build
echo hola > jobs/in/prueba.jpg ; sleep 3 ; ls jobs/out
```

> Si el worker ya no es root, ¿quién es el dueño de `jobs/`? Usa un UID fijo
> (p.ej. `10001`) y dale la propiedad de las carpetas en el host.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
