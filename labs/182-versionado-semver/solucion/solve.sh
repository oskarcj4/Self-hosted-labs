#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/tienda-sdk

cat > scripts/siguiente-version <<'SH'
#!/usr/bin/env bash
# Siguiente versión SemVer según Conventional Commits desde la última vX.Y.Z.
set -euo pipefail

ultima=$(git tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)
if [ -n "$ultima" ]; then
  rango="$ultima..HEAD"; v=${ultima#v}
else
  rango=HEAD; v=0.0.0
fi
IFS=. read -r ma mi pa <<< "$v"

re_rompe='^[a-z]+(\([^)]*\))?!:'
re_feat='^feat(\([^)]*\))?:'
re_fix='^(fix|perf)(\([^)]*\))?:'
nivel=0                                   # 0 nada · 1 patch · 2 minor · 3 major
while IFS= read -r -d '' msg; do
  asunto=${msg%%$'\n'*}
  if [[ $asunto =~ $re_rompe ]] || grep -qE '^BREAKING[ -]CHANGE:' <<< "$msg"; then
    nivel=3
  elif [[ $asunto =~ $re_feat ]]; then
    [ "$nivel" -lt 2 ] && nivel=2
  elif [[ $asunto =~ $re_fix ]]; then
    [ "$nivel" -lt 1 ] && nivel=1
  fi
done < <(git log -z --format=%B "$rango")

case $nivel in
  0) exit 1 ;;
  1) pa=$((pa + 1)) ;;
  2) mi=$((mi + 1)); pa=0 ;;
  3) if [ "$ma" -eq 0 ]; then mi=$((mi + 1)); pa=0; else ma=$((ma + 1)); mi=0; pa=0; fi ;;
esac
echo "$ma.$mi.$pa"
SH
chmod 0755 scripts/siguiente-version

NV=$(scripts/siguiente-version)
echo "Siguiente versión: $NV (no 1.5.0: hay un BREAKING CHANGE en el cuerpo de un fix)"
echo "$NV" > VERSION
python3 - "$NV" <<'PY'
import datetime, sys
nv = sys.argv[1]
sec = f"""## [{nv}] - {datetime.date.today()}
### Cambios incompatibles
- `Pedido.total` es `Decimal` en lugar de `float`: el código que hacía `total + 0.1` falla.

### Nuevas funciones
- `Cliente.carrito()` con descuentos.

### Correcciones
- Totales con céntimos redondeados.
- Se reutiliza la sesión HTTP (rendimiento).

"""
s = open("CHANGELOG.md").read()
i = s.index("## [")
open("CHANGELOG.md", "w").write(s[:i] + sec + s[i:])
PY
git add -A
git -c user.name=analista -c user.email=analista@tienda.local commit -qm "chore(release): $NV"
git -c user.name=analista -c user.email=analista@tienda.local tag -a "v$NV" -m "Release v$NV"
git log --oneline -3 --decorate
echo "solve.sh completado."
