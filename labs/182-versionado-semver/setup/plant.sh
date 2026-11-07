#!/usr/bin/env bash
# Lab 182: el SDK se publica "cuando alguien se acuerda" y con versiones a ojo.
# Desde v1.4.2 hay un cambio incompatible escondido en el cuerpo de un commit.
# El alumno automatiza el cálculo de la siguiente versión (SemVer +
# Conventional Commits) y publica la release correcta.
set -e
H=/home/analista
R=$H/tienda-sdk
install -d -m 0755 /opt/lab/tests
install -m 0755 /opt/lab/setup/casos.sh /opt/lab/tests/casos.sh
git config --system --add safe.directory '*'
git config --system init.defaultBranch main

mkdir -p $R/tienda $R/scripts
cd $R
git init -q
export GIT_AUTHOR_NAME="Equipo SDK" GIT_AUTHOR_EMAIL="sdk@tienda.local"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
c(){ # c FECHA MENSAJE [CUERPO]
  echo "$2" >> tienda/historial.txt
  git add -A
  GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git commit -qm "$2" ${3:+-m "$3"}
}
t(){ GIT_COMMITTER_DATE="$2" git tag -a "$1" -m "Release $1"; }

echo "1.3.0" > VERSION
cat > CHANGELOG.md <<'MD'
# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) · versiones [SemVer](https://semver.org/lang/es/).

## [1.4.2] - 2026-10-02
### Correcciones
- Reintentos con espera exponencial en timeouts.

## [1.4.1] - 2026-09-20
### Correcciones
- El cliente ya no ignora el proxy del sistema.

## [1.4.0] - 2026-09-10
### Nuevas funciones
- `Cliente.pedidos()` acepta filtros por estado.

## [1.3.0] - 2026-08-01
### Nuevas funciones
- Primera versión pública del SDK.
MD
cat > tienda/__init__.py <<'PY'
"""SDK de la tienda."""
from pathlib import Path
__version__ = (Path(__file__).resolve().parent.parent / "VERSION").read_text().strip()
PY
c "2026-08-01T10:00:00" "feat: primera versión pública del SDK"; t v1.3.0 "2026-08-01T10:00:00"
c "2026-09-10T10:00:00" "feat(pedidos): filtros por estado"
echo "1.4.0" > VERSION; c "2026-09-10T11:00:00" "chore(release): 1.4.0"; t v1.4.0 "2026-09-10T11:00:00"
c "2026-09-15T10:00:00" "ci: caché de pip en el pipeline"
git tag deploy-staging                               # etiqueta que NO es una versión
c "2026-09-20T10:00:00" "fix(red): respetar el proxy del sistema"
echo "1.4.1" > VERSION; c "2026-09-20T11:00:00" "chore(release): 1.4.1"; t v1.4.1 "2026-09-20T11:00:00"
c "2026-10-02T10:00:00" "fix: reintentos con espera exponencial"
echo "1.4.2" > VERSION; c "2026-10-02T11:00:00" "chore(release): 1.4.2"; t v1.4.2 "2026-10-02T11:00:00"
# --- sin publicar ---
c "2026-10-10T10:00:00" "docs: ejemplos de paginación"
c "2026-10-14T10:00:00" "feat(carrito): Cliente.carrito() con descuentos"
c "2026-10-20T10:00:00" "fix(pedidos): totales con céntimos redondeados" \
  "Los importes se devuelven ahora como Decimal en lugar de float.

BREAKING CHANGE: Pedido.total es Decimal; el código que hacía total + 0.1 falla."
c "2026-10-25T10:00:00" "perf: reutilizar la sesión HTTP"
c "2026-10-30T10:00:00" "test: pruebas del carrito"
git tag deploy-prod
chown -R analista:analista $R

cat > $H/TAREA.txt <<'TXT'
TAREA · Versionado semántico y releases

~/tienda-sdk usa Conventional Commits. Desde v1.4.2 hay commits sin publicar.
Alguien propone sacar la "1.5.0".

1. Escribe ~/tienda-sdk/scripts/siguiente-version (ejecutable, Bash o Python).
   Ejecutado dentro de un repo git, imprime la SIGUIENTE versión (sin "v"):
   - última versión = la etiqueta vX.Y.Z más alta (por versión, no por fecha);
     ignora etiquetas que no sean vX.Y.Z; sin etiquetas, parte de 0.0.0;
   - mira los commits desde esa etiqueta hasta HEAD:
       cambio incompatible ("tipo!:" o "BREAKING CHANGE:" en el cuerpo) -> MAJOR
       feat -> MINOR      fix o perf -> PATCH      (el resto no publica nada)
   - en 0.y.z un cambio incompatible sube MINOR (0.y -> 0.(y+1).0);
   - sin commits que publiquen: no imprime nada y sale con código 1.
2. Publica la release correcta en ~/tienda-sdk:
   - VERSION con la versión nueva;
   - CHANGELOG.md: sección "## [X.Y.Z] - AAAA-MM-DD" arriba del todo, con
     "### Cambios incompatibles", "### Nuevas funciones" y "### Correcciones";
   - commit "chore(release): X.Y.Z" y etiqueta ANOTADA vX.Y.Z en ese commit;
   - árbol limpio.

El check prueba tu script con repos que no has visto.
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 182 plantado."
