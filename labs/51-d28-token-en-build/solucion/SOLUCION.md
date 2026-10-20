# Solución — Día 28: Sacar un token del build de la imagen

## 1. Dónde está el token

```bash
cd ~/notify
docker history --no-trunc notify/app:1.0 | grep ntf_live   # RUN |1 NOTIFY_TOKEN=ntf_live_... echo ...
docker image inspect notify/app:1.0 --format '{{json .Config.Env}}'   # NOTIFY_TOKEN=...
docker run --rm notify/app:1.0 cat /app/.token                        # en una capa
```

Tres fugas: el `ARG` (queda en el historial), el `ENV` (metadatos) y el `RUN echo` (una capa).

## 2. Dockerfile limpio

```dockerfile
FROM python:3.12-alpine
WORKDIR /app
COPY app.py .
CMD ["python", "-u", "app.py"]
```

## 3. Token en ejecución, como fichero

```bash
install -d -m 0700 secrets
install -m 0600 /dev/null secrets/notify_token.txt
echo 'ntf_live_2c8e5a17f9b4' > secrets/notify_token.txt
```

```yaml
  notifier:
    image: notify/app:1.0
    build: ./app
    environment:
      ROLE: notifier
      NOTIFY_TOKEN_FILE: /run/secrets/notify_token
    secrets:
      - notify_token
    restart: unless-stopped

secrets:
  notify_token:
    file: ./secrets/notify_token.txt
```

## 4. Reconstruir y borrar las imágenes viejas

```bash
docker compose up -d --build
docker images -a          # la imagen anterior queda como <none>
docker image prune -f     # ya no la usa ningún contenedor: se borra
docker builder prune -af  # (recomendado) la caché de build también guarda las capas
```

## 5. Verificar

```bash
for i in $(docker images -aq); do docker save $i | grep -ac ntf_live; done   # todo 0
docker compose exec notifier cat /tmp/status                                # ok (file) gateway ok
```

## Lecciones

- Todo lo que pasa por `ARG`, `ENV`, `COPY` o `RUN` queda en la imagen, aunque
  una capa posterior lo borre (`RUN rm` no elimina la capa anterior).
- Secretos que el build necesita de verdad (p.ej. un token de un registro
  privado): `RUN --mount=type=secret,id=...` de BuildKit, que no deja rastro.
- Secretos de ejecución: en ejecución (ficheros montados, gestores de secretos).
- Si una imagen con el token llegó a un registro: **rotar** el token y borrar esas etiquetas.
