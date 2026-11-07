# Solución — Versionado semántico

## Commits desde v1.4.2

| Commit | Efecto |
|--------|--------|
| `docs: ejemplos de paginación` | nada |
| `feat(carrito): ...` | minor |
| `fix(pedidos): ...` + `BREAKING CHANGE:` en el cuerpo | **major** |
| `perf: reutilizar la sesión HTTP` | patch |
| `test: pruebas del carrito` | nada |

Siguiente versión: **2.0.0**.

## scripts/siguiente-version (núcleo)

```bash
ultima=$(git tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)
# rango = ultima..HEAD, o HEAD si no hay etiquetas (v = 0.0.0)
while IFS= read -r -d '' msg; do
  asunto=${msg%%$'\n'*}
  if [[ $asunto =~ ^[a-z]+(\([^)]*\))?!: ]] || grep -qE '^BREAKING[ -]CHANGE:' <<< "$msg"; then nivel=3
  elif [[ $asunto =~ ^feat(\([^)]*\))?: ]]; then [ "$nivel" -lt 2 ] && nivel=2
  elif [[ $asunto =~ ^(fix|perf)(\([^)]*\))?: ]]; then [ "$nivel" -lt 1 ] && nivel=1
  fi
done < <(git log -z --format=%B "$rango")
# 0: exit 1 · 1: patch · 2: minor · 3: major (o minor si major es 0)
```

## Release

```bash
echo 2.0.0 > VERSION
# CHANGELOG: ## [2.0.0] - fecha, con Cambios incompatibles / Nuevas funciones / Correcciones
git commit -am "chore(release): 2.0.0"
git tag -a v2.0.0 -m "Release v2.0.0"
```

## Por qué

- Las etiquetas **anotadas** guardan autor, fecha y mensaje, y `git describe`
  las prefiere. Las ligeras son sólo un puntero.
- En `0.y.z` la API se considera inestable: por convención, lo incompatible sube la minor.

## Más allá del lab

- Un linter de commits (commitlint) en las PR.
- release-please abre una PR de release con VERSION y CHANGELOG; al fusionarla, etiqueta y publica.
- Versiones de imágenes: `2.0.0`, `2.0` y `2` como etiquetas móviles, más el SHA del commit.
