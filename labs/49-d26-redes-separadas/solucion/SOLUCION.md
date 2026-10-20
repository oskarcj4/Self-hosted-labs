# Solución — Día 26: Separar redes de frontend y backend

## 1. Situación

```bash
cd ~/store
docker network ls | grep store            # store_default (una sola)
docker compose exec web python -c "import socket;socket.create_connection(('db',5432));print('alcanzable')"
```

## 2. compose.yaml con dos redes

```yaml
name: store

services:
  web:
    image: store/app:1.0
    build: ./app
    environment:
      ROLE: web
    ports:
      - "8080:8080"
    networks: [frontend]
    restart: unless-stopped

  api:
    image: store/app:1.0
    environment:
      ROLE: api
    networks: [frontend, backend]
    restart: unless-stopped

  db:
    image: store/app:1.0
    environment:
      ROLE: db
    networks: [backend]
    restart: unless-stopped

networks:
  frontend:
  backend:
    internal: true     # sin salida a internet
```

```bash
docker compose up -d --remove-orphans
docker network rm store_default 2>/dev/null   # ya no se usa
```

## 3. Verificar

```bash
docker compose exec web python -c "import socket;socket.create_connection(('db',5432),timeout=2)"
# socket.gaierror: ... Name does not resolve   <- web ni siquiera resuelve 'db'
curl -s localhost:8080       # web ok -> api ok -> db PONG
```

## Lecciones

- Segmentar por capas limita el movimiento lateral: comprometer `web` ya no da acceso a `db`.
- El DNS interno de Docker sólo resuelve nombres de servicios **de tus mismas redes**.
- `internal: true` corta la salida a internet (útil contra exfiltración desde la BD).
- `web` sigue publicada aunque su red sea `frontend`: publicar puertos y redes internas son cosas distintas.
