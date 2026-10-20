# handoff — stack de pedidos

Documentación del equipo saliente.

- Entrada pública: servicio `web`, puerto **8080** del host.
- `api` y `worker` comparten el volumen `data`.
- `db` está en la red `frontend` (pendiente de mover).

Para levantarlo: `docker compose up -d`.
