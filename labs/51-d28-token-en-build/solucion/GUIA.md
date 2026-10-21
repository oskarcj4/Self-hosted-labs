# Resolución guiada · Día 28

:::piensa Antes de tocar nada
Una imagen es una pila de capas, y **cada capa es para siempre**. Lo que pasa por `ARG`, `ENV`, `COPY` o `RUN` queda registrado, aunque una capa posterior lo borre. Arreglar el Dockerfile no basta: hay que asegurarse de que **ninguna imagen local** (tampoco las viejas `<none>`) conserva el token.
:::

## Paso 1 · ¿Por cuántas vías está el token en la imagen?

**Pregúntate:** el enunciado menciona tres mecanismos. ¿Dónde deja rastro cada uno?

:::pista Cómo comprobarlo
```bash
cd ~/notify
cat app/Dockerfile
docker history --no-trunc notify/app:1.0 | grep -i token      # ARG: queda en el historial
docker image inspect notify/app:1.0 --format '{{json .Config.Env}}'   # ENV: metadatos
docker run --rm notify/app:1.0 ls -la /app                     # RUN/COPY: en una capa
```
:::

## Paso 2 · Dockerfile limpio

**Pregúntate:** ¿qué necesita la imagen para funcionar? El código. El token se le dará **en ejecución**.

:::pista Cómo hacerlo
Quita del Dockerfile el `ARG`, el `ENV` y el `RUN` que escribe el token. Debería quedar algo como:
```dockerfile
FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
CMD ["python", "-u", "app.py"]
```
:::

## Paso 3 · Token en ejecución, como fichero

:::pista Cómo hacerlo
```bash
install -d -m 0700 secrets
install -m 0600 /dev/null secrets/notify_token.txt
# escribe el token en secrets/notify_token.txt
```
En `compose.yaml`, en el servicio `notifier`:
```yaml
    environment:
      ROLE: notifier
      NOTIFY_TOKEN_FILE: /run/secrets/notify_token
    secrets:
      - notify_token
```
y al final:
```yaml
secrets:
  notify_token:
    file: ./secrets/notify_token.txt
```
:::

## Paso 4 · Reconstruye y elimina el pasado

**Pregúntate:** al reconstruir, ¿qué pasa con la imagen vieja? Pierde la etiqueta y queda como `<none>`… con el token dentro.

:::pista Cómo hacerlo
```bash
docker compose up -d --build
docker images -a
docker image prune -f
docker builder prune -af
```
La caché de build también guarda capas: límpiala.
:::

## Paso 5 · Verifica en todas las imágenes

```bash
for i in $(docker images -aq); do echo "$i $(docker save $i | grep -ac '<prefijo-del-token>')"; done
docker compose exec notifier cat /tmp/status
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **`RUN rm` no borra nada**: la capa anterior sigue en la imagen.
- **Secretos que el build necesita de verdad**: `RUN --mount=type=secret` de BuildKit, que no deja rastro.
- **Secretos de ejecución, en ejecución.**
- Si la imagen llegó a un registro: **rotar** el token y borrar esas etiquetas.

## Si te atascas

- `prune` no borra una imagen: algún contenedor (aunque esté parado) la usa. `docker ps -a`.
