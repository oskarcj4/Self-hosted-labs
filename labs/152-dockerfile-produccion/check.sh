#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 152.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
APP=/home/analista/app
DF=$APP/Dockerfile

echo "== Lab 152 · Dockerfile de producción — comprobación =="

# 1) Construye sin error
if docker build -t app:prod "$APP" >/tmp/build152.log 2>&1; then
  ok "La imagen se construye (docker build)."
else
  no "docker build falla. Mira: tail -20 /tmp/build152.log"
  echo "Resultado: $pass superados, $((fail+5)) pendientes."; exit 1
fi

# 2) Multi-stage (dos o más FROM)
if [ "$(grep -ciE '^\s*FROM ' "$DF")" -ge 2 ]; then
  ok "Multi-stage: hay dos o más etapas FROM."
else
  no "El Dockerfile no es multi-stage (necesita dos o más 'FROM')."
fi

# 3) Base final ligera (slim/alpine/distroless en el último FROM)
LASTFROM=$(grep -iE '^\s*FROM ' "$DF" | tail -1)
if echo "$LASTFROM" | grep -qiE 'slim|alpine|distroless'; then
  ok "La etapa final parte de una base ligera."
else
  no "La etapa final debería usar una base ligera (p. ej. python:3.12-slim-bookworm)."
fi

# 4) Usuario no root en la imagen construida
U=$(docker inspect --format '{{.Config.User}}' app:prod 2>/dev/null)
if [ -n "$U" ] && [ "$U" != "root" ] && [ "$U" != "0" ]; then
  ok "La imagen corre como usuario no root ('$U')."
else
  no "La imagen corre como root: añade un usuario y 'USER'."
fi

# 5) HEALTHCHECK declarado
if [ "$(docker inspect --format '{{if .Config.Healthcheck}}yes{{end}}' app:prod 2>/dev/null)" = "yes" ]; then
  ok "La imagen define HEALTHCHECK."
else
  no "Falta HEALTHCHECK en el Dockerfile."
fi

# 6) Etiqueta OCI
if grep -qiE 'org\.opencontainers\.image' "$DF"; then
  ok "Declara metadatos OCI (org.opencontainers.image.*)."
else
  no "Añade al menos una etiqueta LABEL org.opencontainers.image.*"
fi

# 7) .dockerignore útil
if [ -f "$APP/.dockerignore" ] && grep -qE '\.git' "$APP/.dockerignore"; then
  ok "Hay .dockerignore y excluye .git."
else
  no "Crea ~/app/.dockerignore excluyendo .git y __pycache__."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Dockerfile de producción: ligero, sin root, observable y trazable."; exit 0; } || exit 1
