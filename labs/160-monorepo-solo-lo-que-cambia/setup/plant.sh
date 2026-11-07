#!/usr/bin/env bash
# Lab 160: monorepo con tres servicios y una librería común. El pipeline
# construye y despliega TODO en cada push (lento y arriesgado). El alumno
# escribe ci/changed.sh y hace que el pipeline construya sólo lo afectado.
set -e
H=/home/analista
M=$H/monorepo
mkdir -p "$M"/{services/catalogo,services/pagos,services/notificaciones,libs/comun,docs,ci} /var/lib/ci/artefactos
chmod 1777 /var/lib/ci/artefactos

cat > "$M/libs/comun/util.py" <<'PY'
def precio(cents):
    return f"{cents / 100:.2f} EUR"
PY
for s in catalogo pagos; do
cat > "$M/services/$s/app.py" <<PY
from libs.comun.util import precio
print("$s", precio(1999))
PY
printf 'libs/comun\n' > "$M/services/$s/deps.txt"
done
cat > "$M/services/notificaciones/app.py" <<'PY'
print("notificaciones: ok")
PY
: > "$M/services/notificaciones/deps.txt"
cat > "$M/docs/arquitectura.md" <<'MD'
# Arquitectura
- services/<nombre>/  : un servicio desplegable por carpeta.
- services/<nombre>/deps.txt : rutas del repo de las que depende (una por línea).
- libs/               : código compartido; NO se despliega solo.
MD
cat > "$M/README.md" <<'MD'
# Monorepo de la tienda
Servicios en services/, librerías en libs/. Pipeline: ci/pipeline.sh (ci-run).
MD
cat > "$M/ci/build.sh" <<'SH'
#!/usr/bin/env bash
# build.sh <servicio> — "construye y despliega" un servicio (simulado: ~4 s).
set -euo pipefail
S="$1"
[ -d "services/$S" ] || { echo "no existe services/$S"; exit 1; }
echo ">> build + deploy de $S"
python3 -c "import sys; sys.path.insert(0,'.'); exec(open('services/$S/app.py').read())" >/dev/null
sleep 4
mkdir -p "${ARTEFACTOS:-/var/lib/ci/artefactos}"
echo "$S ${CI_HEAD:-local}" > "${ARTEFACTOS:-/var/lib/ci/artefactos}/$S"
SH
cat > "$M/ci/pipeline.sh" <<'SH'
#!/usr/bin/env bash
# Pipeline del monorepo. Variables del CI: CI_BASE (commit anterior), CI_HEAD.
set -euo pipefail
for d in services/*/; do
  bash ci/build.sh "$(basename "$d")"
done
SH
chmod 0755 "$M"/ci/*.sh
chown -R analista:analista "$M"
cd "$M"
runuser -u analista -- git init -q -b main
runuser -u analista -- git config user.name "Analista"
runuser -u analista -- git config user.email analista@tienda.local
runuser -u analista -- git add -A
runuser -u analista -- git commit -qm "Monorepo: catalogo, pagos, notificaciones y libs/comun"
echo "Typo" >> docs/arquitectura.md
runuser -u analista -- git commit -qam "docs: nota"

cat > $H/TAREA.txt <<'TXT'
TAREA · Monorepo: construir sólo lo que cambió (~/monorepo)

Cada push reconstruye y redespliega los 3 servicios, aunque sólo cambies un
README (prueba: ci-run). Queremos:

1. ci/changed.sh <base> <head>: imprime, uno por línea y ordenados, los
   servicios afectados por los cambios entre esos dos commits:
   - un fichero dentro de services/<s>/   -> afecta a <s>
   - un fichero dentro de una ruta listada en services/<s>/deps.txt
     (p. ej. libs/comun)                  -> afecta a <s>
   - docs/, README.md...                  -> no afecta a nadie
   - un servicio nuevo (carpeta nueva en services/) también cuenta.
2. ci/pipeline.sh usa ci/changed.sh "$CI_BASE" "$CI_HEAD" y construye sólo
   esos (si no hay ninguno, termina bien sin construir nada).
3. Haz commit.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 160 plantado."
