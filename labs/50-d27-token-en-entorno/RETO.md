# Día 27 — Token del entorno a un fichero secreto

> 30 días de DevSecOps · Docker · Secretos en contenedores

## Escenario

`uploader` (stack `files`, en `~/files`) se autentica contra el almacenamiento
con un token que está **escrito en `compose.yaml`** como variable de entorno.
Eso significa que el token:

- está en el repositorio junto al resto del YAML,
- se ve con `docker inspect` y `docker compose config`,
- lo hereda cualquier proceso que lance el contenedor.

La app ya soporta leerlo de un fichero (`UPLOADER_API_TOKEN_FILE`).

## Objetivos

1. El token no debe estar en el entorno del contenedor ni en `compose.yaml`/`.env`.
2. Debe llegar como **fichero montado en sólo lectura**, indicado con
   `UPLOADER_API_TOKEN_FILE`.
3. En el host, el fichero con el token debe ser `0600` (o `0400`).
4. `uploader` sigue autenticándose: `/tmp/status` → `ok (file) storage ok`.

## Comandos que te pueden servir

```bash
cd ~/files && cat compose.yaml app/app.py
docker inspect files-uploader-1 --format '{{range .Config.Env}}{{println .}}{{end}}'
docker compose exec uploader cat /tmp/status
docker compose up -d
```

> Los *secrets* de Compose (`secrets:` con `file:`) montan el fichero en
> `/run/secrets/<nombre>` en sólo lectura. Créalo ya con permisos cerrados
> (`install -m 0600 /dev/null ...`).

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
