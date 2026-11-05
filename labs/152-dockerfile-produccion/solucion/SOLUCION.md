# Solución — Dockerfile de producción

## Dockerfile final

```dockerfile
# ---- etapa de build ----
FROM python:3.12-slim-bookworm AS build
WORKDIR /app
COPY app.py .
RUN python -m compileall -q app.py

# ---- etapa final ----
FROM python:3.12-slim-bookworm AS final
LABEL org.opencontainers.image.title="allsafe-api" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.source="https://allsafe.example/allsafe-api"
RUN useradd --system --no-create-home --uid 10001 appuser
WORKDIR /app
COPY --from=build /app/app.py /app/app.py
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')" || exit 1
CMD ["python", "app.py"]
```

`.dockerignore`:

```
.git
__pycache__/
*.pyc
README.txt
```

## Por qué cada pieza

- **slim en la etapa final**: `python:3.12` pesa ~1 GB; `slim` ~120 MB. Menos
  superficie, menos CVEs que escanear.
- **Multi-stage**: aquí el build solo precompila, pero en una app real esa etapa
  compila dependencias (gcc, headers) que NO deben viajar a la imagen final.
- **`useradd` + `USER`**: el proceso no corre como root. UID alto y fijo (10001)
  para que el orquestador pueda imponer `runAsNonRoot`.
- **HEALTHCHECK**: sin curl en slim, se usa `python -c urllib`. Docker marca el
  contenedor `unhealthy` si `/healthz` no responde.
- **LABEL OCI**: `version` y `source` dejan trazable qué corre en producción.

## Más allá del lab

- Fija la base por digest (`python:3.12-slim-bookworm@sha256:...`) para builds
  reproducibles.
- Añade `--require-hashes` al `pip install` cuando haya dependencias (ver lab 140).
- Escanea la imagen con trivy y genera SBOM con syft (ver lab 142).
