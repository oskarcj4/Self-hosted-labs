# Resolución guiada · Día 29

:::piensa Antes de tocar nada
Una imagen de producción debe llevar **lo justo para funcionar** y nada más: ni depuradores, ni pruebas, ni ficheros `.env`. Y debe ser **reproducible**: si la base cambia sola cada vez que sale una versión, nunca sabes qué estás desplegando. Revisa el Dockerfile línea a línea preguntando: ¿esto hace falta en producción?
:::

## Paso 1 · Inventario de problemas

:::pista Cómo comprobarlo
```bash
cd ~/reports
cat app/Dockerfile
ls -la app/
docker image inspect reports/worker:latest --format '{{json .Config.Env}} {{json .Config.ExposedPorts}}'
docker run --rm --entrypoint ls reports/worker:latest -a /app
```
Haz una lista: base flotante, `DEBUG`, `EXPOSE`, y lo que entra con `COPY .`.
:::

## Paso 2 · Fija la base

**Pregúntate:** ¿qué diferencia hay entre `python:3-alpine` y `python:3.12-alpine`? La primera salta a 3.13, 3.14… sin avisar. Aún más estricto: fijar por digest (`@sha256:…`).

## Paso 3 · Quita la depuración

**Pregúntate:** si `DEBUG=1` abre un depurador remoto, ¿qué pasa si quito la variable? El depurador no se activa. Y sin depurador, `EXPOSE 5678` sobra.

## Paso 4 · Copia sólo lo necesario

**Pregúntate:** ¿qué usa el worker para funcionar? `worker.py` y `data/`. Todo lo demás no debe entrar.

:::pista Cómo hacerlo
```dockerfile
FROM python:3.12-alpine
WORKDIR /app
COPY worker.py .
COPY data/ data/
CMD ["python", "-u", "worker.py"]
```
Y como red de seguridad, `app/.dockerignore`:
```
debug/
tests/
.env*
Dockerfile
.dockerignore
```
Así, aunque alguien vuelva a escribir `COPY . /app`, lo sensible no viaja al build.
:::

## Paso 5 · Reconstruye y verifica

```bash
docker compose up -d --build
docker run --rm --entrypoint ls reports/worker:latest -a /app
docker image inspect reports/worker:latest --format '{{json .Config.Env}} {{json .Config.ExposedPorts}}'
sleep 2; cat out/report.txt
docker image prune -f
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Etiquetas flotantes** (`latest`, `3-alpine`) = builds no reproducibles.
- **`COPY` explícito + `.dockerignore`**: defensa en dos capas.
- **Producción ≠ desarrollo**: sin depuradores, sin pruebas, sin `.env`.
- `.env.debug` estuvo en la imagen: en un caso real, **rotar** la contraseña de staging.

## Si te atascas

- El worker no genera el informe: comprueba que copiaste `data/` con la misma ruta que espera `worker.py`.
