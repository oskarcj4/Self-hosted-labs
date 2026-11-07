# Solución — Compose para un VPS

## Problemas y arreglos

| Problema | Arreglo |
|----------|---------|
| `db` y `app` publican puertos | sólo `proxy: ports: ["80:80"]` |
| sin volumen | `pgdata:/var/lib/postgresql/data` |
| contraseña en el YAML y en `docker inspect` | secret de fichero + `*_PASSWORD_FILE`, contraseña nueva |
| la app arranca antes que la base de datos | healthcheck `pg_isready` + `condition: service_healthy` |
| nadie reinicia lo que se cae | `restart: unless-stopped` |
| logs sin límite | `json-file` con `max-size: 10m`, `max-file: 3` |

El `compose.yaml` completo está en `solve.sh`.

## Por qué

- Un puerto publicado salta las reglas de entrada de ufw/iptables del host:
  Docker añade sus propias reglas antes. No publicar es la única garantía.
- Los secrets de Compose se montan como fichero en `/run/secrets/`. No
  aparecen en `docker inspect` ni en el entorno de procesos hijos.
- `depends_on` sin condición sólo espera a que el contenedor **exista**, no a
  que la base de datos acepte conexiones.

## Más allá del lab

- TLS en el proxy: Caddy o Traefik con Let's Encrypt automático.
- `docker compose --profile` para servicios opcionales (adminer sólo cuando haga falta).
- Si crecéis a varios servidores, el siguiente paso es un orquestador. Este
  compose ya tiene casi todo lo que pide Kubernetes: healthchecks, secrets y
  volúmenes.
