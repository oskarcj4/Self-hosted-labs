# Solución — Día 25: Acotar un secreto de Compose

## 1. Ver a quién llega

```bash
cd ~/analytics
docker compose config | grep -B12 'source: api_token' | grep -E '^  [a-z]+:$'
for s in web worker reporter; do echo "== $s"; docker compose exec $s cat /run/secrets/api_token; done
```

El anclaje `x-app` incluye `secrets:` y lo heredan `web`, `worker` y `reporter`.

## 2. Sacar el secreto del anclaje y dárselo sólo a quien lo usa

```yaml
x-app: &app
  image: analytics/app:1.0
  restart: unless-stopped

services:
  upstream:
    ...
  web:
    <<: *app
    environment:
      ROLE: web
    ports:
      - "8080:8080"

  worker:
    <<: *app
    environment:
      ROLE: worker

  reporter:
    <<: *app
    environment:
      ROLE: reporter
    secrets:
      - api_token

secrets:
  api_token:
    file: ./secrets/api_token.txt
```

```bash
docker compose up -d       # recrea web, worker y reporter
```

## 3. Verificar

```bash
docker compose exec web ls /run/secrets       # No such file or directory
docker compose exec worker ls /run/secrets    # idem
sleep 6; docker compose exec reporter cat /tmp/status   # ... ok upstream ok
```

## Lecciones

- Mínimo privilegio también para secretos: cada servicio, sólo los suyos.
- Los anclajes y `extends` son cómodos pero propagan cosas sin que se vean:
  revisa siempre `docker compose config`.
- Si `web` tuvo el token, en un caso real hay que **rotarlo**.
