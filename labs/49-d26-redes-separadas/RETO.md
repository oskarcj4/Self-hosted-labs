# Día 26 — Separar redes de frontend y backend

> 30 días de DevSecOps · Docker · Secretos en contenedores

## Escenario

La tienda `store` (`~/store`) tiene tres capas: `web` (pública, `:8080`),
`api` y `db`. Todas viven en la red por defecto del proyecto, así que `web`
—la pieza más expuesta— puede hablar **directamente** con la base de datos:

```bash
docker compose exec web python -c "import socket;s=socket.create_connection(('db',5432));s.send(b'PING\n');print(s.recv(9))"
```

## Objetivos

1. Crea dos redes: `frontend` (web + api) y `backend` (api + db).
2. `web` y `db` no deben compartir ninguna red: desde `web` no se llega a `db:5432`.
3. `api` es el único puente entre ambas.
4. La cadena sigue funcionando: `curl localhost:8080` →
   `web ok -> api ok -> db PONG`.
5. Extra (opcional): la red `backend` sin salida a internet (`internal: true`).

## Comandos que te pueden servir

```bash
cd ~/store && cat compose.yaml
docker network ls
docker compose up -d
docker inspect store-web-1 --format '{{json .NetworkSettings.Networks}}' | jq 'keys'
curl -s localhost:8080
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
