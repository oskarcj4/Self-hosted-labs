# Compose para un VPS

> DevOps · Docker Compose · healthchecks · volúmenes · secrets · restart · logs

## Escenario

Para el primer cliente basta un VPS con Docker: no hace falta Kubernetes. El
problema es que `~/vps/compose.yaml` se copió **tal cual del portátil** de
desarrollo:

- PostgreSQL publicado en `0.0.0.0:5432`: cualquiera en internet puede intentar entrar.
- La contraseña en el YAML, que además está en git.
- Sin volumen: un `docker compose down` borra todos los pedidos.
- La app arranca antes que la base de datos, falla y nadie la reinicia.
- Sin límite de logs: en unas semanas el disco se llena (lab 178).

Docker corre **dentro** del lab: nada toca tu máquina.

## Objetivos

1. Sólo `proxy` publica un puerto (80).
2. Volumen con nombre para `/var/lib/postgresql/data`.
3. Contraseña como **secret** de fichero, con `POSTGRES_PASSWORD_FILE` y
   `DB_PASSWORD_FILE`. Que no esté en el YAML ni en el entorno de los
   contenedores, y que sea nueva.
4. Healthcheck en `db` y `app`; `app` espera con `condition: service_healthy`.
5. `restart: unless-stopped` (o `always`) en todos.
6. Logs `json-file` con `max-size` en todos.

El check levanta el stack, crea un pedido, hace `down` + `up` y lo busca.

## Pistas

```bash
cd ~/vps
docker compose up -d --build; docker compose ps -a; docker compose logs app
docker compose config            # el modelo final, con todo resuelto
docker compose up -d --wait      # espera a que todo esté sano
docker inspect "$(docker compose ps -q db)" -f '{{json .Config.Env}}'
```

```yaml
x-logs: &logs                    # ancla YAML: defínelo una vez, úsalo en todos
  driver: json-file
  options: { max-size: "10m", max-file: "3" }
secrets:
  db_password:
    file: ./secretos/db_password.txt
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
