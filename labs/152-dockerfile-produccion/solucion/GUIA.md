# Resolución guiada · Lab 152

:::piensa Qué pide producción
Cada requisito ataca un problema real. Base ligera: menos tamaño y menos
paquetes con CVEs. Sin root: si alguien escapa del proceso, no es root dentro
del contenedor. Healthcheck: Docker y el orquestador saben si la app está viva
de verdad, no sólo si el proceso existe. Etiquetas: sabes qué versión y de qué
código es cada imagen.
:::

**El plan:** (1) ver el Dockerfile actual, (2) escribir el de producción,
(3) el `.dockerignore` y (4) construir y probar.

## Paso 1 · El Dockerfile de partida

:::pista Cómo hacerlo
```bash
cd ~/app
cat Dockerfile
ls -la
docker images python
```
**Qué deberías ver:** `FROM python:3.12` (la imagen completa, cientos de MB),
sin `USER`, sin `HEALTHCHECK`. Y `python:3.12-slim-bookworm` ya cargada.
:::

## Paso 2 · El Dockerfile de producción

:::pista Cómo hacerlo
```dockerfile
# ---- etapa de build ----
FROM python:3.12-slim-bookworm AS build
WORKDIR /app
COPY app.py .
RUN python -m compileall -q app.py

# ---- etapa final ----
FROM python:3.12-slim-bookworm AS final
LABEL org.opencontainers.image.title="allsafe-api" \
      org.opencontainers.image.version="1.0.0"
RUN useradd --system --no-create-home --uid 10001 appuser
WORKDIR /app
COPY --from=build /app/app.py /app/app.py
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1
CMD ["python", "app.py"]
```

| Pieza | Qué hace |
|---|---|
| Dos `FROM … AS …` | Dos etapas. La primera prepara el artefacto; sólo la última forma la imagen. Con una app que necesite compilar o instalar dependencias, las herramientas se quedan en la primera. |
| `python -m compileall` | Precompila el código a *bytecode*: un ejemplo de trabajo que se hace en la etapa de build. |
| `LABEL org.opencontainers.image.*` | Metadatos estándar (OCI): título, versión, origen. Los leen registros y escáneres. |
| `useradd --system --uid 10001` | Un usuario de sistema con UID fijo y alto, sin carpeta personal. |
| `COPY --from=build` | Copia desde la etapa de build, no desde tu carpeta. |
| `USER appuser` | Todo lo que viene después, incluido el proceso de la app, corre como ese usuario. Va después de crear el usuario y copiar los ficheros. |
| `EXPOSE 8000` | Documenta el puerto (no lo publica). |
| `HEALTHCHECK` | Cada 10 s, Docker ejecuta ese comando dentro del contenedor; tras 3 fallos seguidos lo marca `unhealthy`. Se usa Python porque la imagen slim no trae `curl`. `\|\| exit 1`: cualquier error cuenta como fallo. |
| `CMD ["python", "app.py"]` | Formato con corchetes: ejecuta el programa directamente, sin una shell en medio. |
:::

## Paso 3 · `.dockerignore`

:::pista Cómo hacerlo
```bash
cat > ~/app/.dockerignore <<'EOF'
.git
__pycache__/
*.pyc
EOF
```
`docker build` envía al motor toda la carpeta (el *contexto*) antes de
construir. `.dockerignore` dice qué no enviar: el historial de git y las
cachés no tienen nada que hacer en una imagen, y además hacen el build más
lento.
:::

## Paso 4 · Construye y prueba

```bash
docker build -t app:prod .
docker images app:prod
docker run --rm -d -p 8000:8000 --name t app:prod
curl -s localhost:8000/healthz
sleep 12; docker inspect --format '{{.State.Health.Status}} user={{.Config.User}}' t
docker rm -f t
bash /opt/lab/check.sh
```
**Qué deberías ver:** `{"status": "ok"}`, y tras la primera comprobación
`healthy user=appuser`.

## Cómo actuar en una situación así

- Base ligera + multi-stage es la mayor palanca contra tamaño y CVEs.
- En Kubernetes, `runAsNonRoot: true` rechaza imágenes que corren como root:
  mejor resolverlo aquí.
- En una app con dependencias: fija versiones y usa un lockfile; instala en la
  etapa de build y copia sólo el resultado.

## Si te atascas

- **`docker inspect` da `user=` vacío:** el `USER` está en la etapa de build,
  no en la final.
- **El contenedor queda `unhealthy`:** prueba el comando del healthcheck a mano
  con `docker exec t python -c "…"`; la app tiene que escuchar en el 8000.
- **`useradd: command not found`:** usaste una base Alpine; ahí es `adduser -D`.
