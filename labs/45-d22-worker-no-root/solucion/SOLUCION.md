# Solución — Día 22: Worker sin root

## 1. Comprobar

```bash
cd ~/media
docker compose exec thumbnailer id      # uid=0(root)
ls -ln jobs                             # carpetas de root (0) 0755
```

## 2. Usuario sin privilegios en la imagen

`thumbnailer/Dockerfile`:

```dockerfile
FROM python:3.12-alpine
RUN addgroup -S -g 10001 thumb && adduser -S -D -H -u 10001 -G thumb thumb
WORKDIR /app
COPY worker.py .
USER 10001:10001
CMD ["python", "-u", "worker.py"]
```

- `USER` numérico: funciona igual aunque el usuario no exista en el host y
  permite comprobar "no es root" sin resolver nombres.

## 3. Permisos de las carpetas del bind mount

En un bind mount cuentan los UID **numéricos**. El worker (10001) tiene que
poder leer `in/` y escribir en `in/` (mover), `out/` y `done/`:

```bash
sudo chown -R 10001:10001 jobs
sudo chmod 0750 jobs jobs/*        # nada de 777
```

## 4. Reconstruir y probar

```bash
docker compose up -d --build
docker compose exec thumbnailer id          # uid=10001
echo hola | sudo tee jobs/in/prueba.jpg >/dev/null
sleep 3; sudo ls jobs/out jobs/done
docker compose logs thumbnailer --tail 3
```

## Lecciones

- Root en el contenedor es root del kernel del host (salvo userns-remap/rootless):
  cualquier escape o bind mount lo convierte en root real.
- `USER` en la imagen + UID fijo + propiedad de los datos para ese UID.
- `chmod 777` "para que funcione" cambia un problema por otro.
