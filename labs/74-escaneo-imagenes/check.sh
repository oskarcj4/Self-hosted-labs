#!/usr/bin/env bash
# Validador del Lab 74. Escanea la imagen inventario-api:local con grype
# (base de datos local) y exige 0 CRITICAL, con la app aún funcionando.
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export GRYPE_DB_CACHE_DIR=/opt/grype/db GRYPE_DB_AUTO_UPDATE=false GRYPE_DB_VALIDATE_AGE=false
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
end(){ echo "---------------------------------------"; echo "Resultado: $pass superados, $fail pendientes."; }

echo "== Lab 74 · Escaneo de imágenes — comprobación =="

if ! command -v grype >/dev/null; then no "No encuentro grype."; end; exit 1; fi
if ! docker image inspect inventario-api:local >/dev/null 2>&1; then
  no "No existe la imagen inventario-api:local (constrúyela: docker build -t inventario-api:local /srv/api)."
  end; exit 1
fi

# La app tiene que seguir arrancando.
out=$(docker run --rm inventario-api:local 2>/dev/null | tr -d '\r')
[ "$out" = "inventario-api ok" ] && ok "La app arranca: \"$out\"." \
  || no "La app no arranca como debe (esperaba 'inventario-api ok', salió: '${out:-nada}')."

# Escaneo. Usamos JSON para contar por severidad.
J=$(mktemp)
if ! grype -q inventario-api:local -o json > "$J" 2>/tmp/grype.err; then
  no "grype falló: $(tail -1 /tmp/grype.err)"; rm -f "$J"; end; exit 1
fi
crit=$(jq '[.matches[].vulnerability.severity] | map(select(. == "Critical")) | length' "$J")
high=$(jq '[.matches[].vulnerability.severity] | map(select(. == "High")) | length' "$J")
echo "  · CVE encontrados: ${crit} CRITICAL, ${high} HIGH"
if [ "$crit" -eq 0 ]; then
  ok "0 vulnerabilidades CRITICAL: la imagen pasa el gate."
else
  worst=$(jq -r '[.matches[] | select(.vulnerability.severity == "Critical")
            | "\(.artifact.name) \(.vulnerability.id)"] | unique | .[0:3] | join(", ")' "$J")
  no "Siguen quedando $crit CRITICAL (p. ej.: $worst)."
fi
rm -f "$J"

# La base vieja no debe seguir en el Dockerfile versionado.
if grep -qiE '^\s*FROM\s+python:3\.12\.0-alpine3\.18' /srv/api/Dockerfile 2>/dev/null; then
  no "El Dockerfile de /srv/api sigue apuntando a la base vieja (python:3.12.0-alpine3.18). Arréglalo ahí, no sólo en una imagen suelta."
else
  ok "El Dockerfile ya no usa la base vieja python:3.12.0-alpine3.18."
fi

end
[ "$fail" -eq 0 ] && { echo "🎉 Imagen a 0 CRITICAL y app funcionando. Gate de seguridad superado."; exit 0; } || exit 1
