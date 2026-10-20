# Solución — Día 24: Webhook sin socket de Docker

## 1. Medir el riesgo

```bash
cd ~/deployhook
curl -s localhost:8090/debug/containers          # lista los contenedores del host
docker compose exec webhook python - <<'EOF'
import socket; s=socket.socket(socket.AF_UNIX); s.connect("/var/run/docker.sock")
s.sendall(b"GET /version HTTP/1.0\r\n\r\n"); print(s.recv(300))
EOF
```

Con el socket se puede pedir al daemon, p.ej., crear un contenedor con
`privileged` y `-v /:/host`: root en el host. Montar `docker.sock` equivale a
dar root del host al contenedor.

## 2. ¿Lo usa?

Para su función (registrar eventos) no. El socket sólo alimenta un endpoint de
diagnóstico que nadie usa.

## 3. Quitar el montaje

```yaml
services:
  webhook:
    image: deployhook/webhook:1.2
    build: ./webhook
    ports:
      - "8090:8090"
    volumes:
      - ./events:/events
    restart: unless-stopped
```

```bash
docker compose up -d
curl -s localhost:8090/debug/containers          # webhook ok (ya no lista nada)
curl -s -X POST -d '{"repo":"prueba"}' localhost:8090/hook && tail -1 events/events.log
```

## Lecciones

- `docker.sock` montado = root en el host. Y en un servicio expuesto a internet, peor.
- `:ro` en el socket **no** protege: sólo impide borrar el fichero, la API sigue entera.
- Si de verdad hay que automatizar Docker: un proxy del socket que sólo permita
  las llamadas necesarias (p.ej. reiniciar un contenedor concreto), Docker
  rootless, o que lo haga el pipeline de CI y no un servicio público.
