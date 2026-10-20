# Día 25 — Acotar un secreto de Compose

> 30 días de DevSecOps · Docker · Secretos en contenedores

## Escenario

El stack `analytics` (`~/analytics`) usa un secreto de Compose, `api_token`,
para que `reporter` se autentique contra una API externa (`upstream`). Para
"no repetir YAML", alguien lo puso en un anclaje común (`x-app`) y ahora lo
reciben también `web` (expuesto en `:8080`) y `worker`, que no lo usan.

Si `web` cae, el atacante se lleva un token que `web` ni siquiera necesitaba.

## Objetivos

1. Sólo `reporter` debe tener `/run/secrets/api_token`.
2. `web`, `worker` y `upstream` no deben recibir ningún secreto.
3. `reporter` sigue autenticándose (`/tmp/status` → `ok upstream ok`).
4. Todos los servicios siguen corriendo; el panel sigue en `:8080`.
5. El cambio debe estar en `compose.yaml`.

## Comandos que te pueden servir

```bash
cd ~/analytics && cat compose.yaml
docker compose config            # el YAML final, con los anclajes ya expandidos
for s in web worker reporter upstream; do echo "== $s"; docker compose exec $s ls /run/secrets 2>&1; done
docker compose exec reporter cat /tmp/status
docker compose up -d
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
