# Resolución guiada · Lab 183

:::piensa ¿Qué necesita un servicio para vivir solo en un VPS?
Nadie va a estar mirando. Tiene que arrancar en orden, levantarse solo si se
cae, guardar los datos fuera del contenedor, no ocupar todo el disco con logs
y exponer a internet sólo la puerta de entrada.
:::

## Paso 1 · Puertos

:::pista Cómo hacerlo
Quita `ports` de `db` y `app`. Dentro de la red de Compose se ven por el
nombre del servicio (`db:5432`, `app:8000`). Sólo `proxy` publica el 80.
:::

## Paso 2 · Datos

:::pista Cómo hacerlo
```yaml
    volumes:
      - pgdata:/var/lib/postgresql/data
volumes:
  pgdata:
```
`down` conserva los volúmenes; sólo `down -v` los borra.
:::

## Paso 3 · Contraseña

:::pista Cómo hacerlo
```bash
mkdir secretos; (umask 077; openssl rand -base64 24 > secretos/db_password.txt)
```
En `db`: `POSTGRES_PASSWORD_FILE: /run/secrets/db_password`. En `app`:
`DB_PASSWORD_FILE` (la app ya lo soporta). Los dos con `secrets: [db_password]`.
Añade `secretos/` al `.gitignore`.
:::

## Paso 4 · Orden y salud

:::pista Cómo hacerlo
`db` con `pg_isready -U postgres`, y `app` con un `python -c` que pida
`/salud` (la imagen slim no trae curl). En `app`, `depends_on: {db: {condition: service_healthy}}`.
:::

## Paso 5 · Reinicios y logs

:::pista Cómo hacerlo
`restart: unless-stopped` en todos, y un ancla `x-logs` con `max-size` y `max-file`
que repites con `logging: *logs`.
:::

## Cómo actuar en una situación así

- Firewall del VPS también (ufw, lab 113): defensa en profundidad.
- Backups del volumen: `pg_dump` a otro sitio con un timer, y prueba a restaurar (lab 176).
- Actualizar es `docker compose pull && docker compose up -d`. Fija las versiones de las imágenes para que sea predecible.
