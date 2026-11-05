# Dockerfile de producción

> Imagen y ejecución · multi-stage · no root · HEALTHCHECK · OCI labels · .dockerignore

## Escenario

La API `allsafe-api` (en `~/app`) tiene un Dockerfile "de desarrollo": parte de
la imagen gorda `python:3.12`, corre como **root**, no declara puerto ni
healthcheck ni metadatos. Para producción eso es peso de más, superficie de
ataque de más y cero observabilidad. Conviértelo en un Dockerfile de producción.

- **Multi-stage**: una etapa prepara el artefacto; la final solo lleva lo justo
  para ejecutar. Menos tamaño, menos CVEs.
- **No root**: si alguien escapa del proceso, no cae en un root del contenedor.
- **HEALTHCHECK**: Docker (y el orquestador) sabe si el proceso está vivo y listo.
- **Metadatos OCI** (`org.opencontainers.image.*`): trazabilidad de versión y origen.
- **`.dockerignore`**: no metas `.git`, cachés ni basura en el contexto de build.

## Objetivos

1. `~/app/Dockerfile` multi-stage (dos o más `FROM`), base final ligera
   (`python:3.12-slim-bookworm`, ya precargada).
2. Usuario no root (`USER`).
3. `HEALTHCHECK` contra `/healthz` en el puerto 8000.
4. Al menos una etiqueta `org.opencontainers.image.*` y `EXPOSE 8000`.
5. `~/app/.dockerignore` que excluya `.git` y `__pycache__`.

## Pistas

```bash
cd ~/app
docker build -t app:prod .
docker run --rm -d -p 8000:8000 --name t app:prod
curl -s localhost:8000/healthz        # {"status": "ok"}
docker inspect --format '{{.Config.User}}' app:prod   # no vacío, no root
docker rm -f t
```

> La app no usa librerías externas (solo la stdlib), así que no hay `pip install`
> que fijar aquí; en una real, fija versiones y usa un lockfile.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
