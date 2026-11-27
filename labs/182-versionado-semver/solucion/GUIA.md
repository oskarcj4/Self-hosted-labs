# Resolución guiada · Lab 182

:::piensa ¿1.5.0?
Mirando sólo los asuntos (`git log --oneline`) sí: hay un `feat` y varios
`fix`. Pero el cuerpo de `fix(pedidos): totales...` tiene un pie
`BREAKING CHANGE:`: `Pedido.total` cambia de tipo. Es una **2.0.0**.
:::

## Paso 1 · La última versión

:::pista Qué hacer
`git tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1`.
`sort -V` ordena por versión: `v1.10.0` va después de `v1.9.0`. `git describe`
no sirve: elige la etiqueta más cercana, no la más alta, y no ignora `deploy-prod`.
:::

## Paso 2 · Clasificar los commits

:::pista Cómo hacerlo
`git log -z --format=%B ULTIMA..HEAD` y lee con `while IFS= read -r -d '' msg`.
- `^[a-z]+(\(...\))?!:` en el asunto, o `^BREAKING CHANGE:` en cualquier línea: major.
- `^feat(\(...\))?:` es minor; `^(fix|perf)(\(...\))?:` es patch.
- Gana el nivel más alto. Con major 0, un cambio incompatible sube la minor.
:::

## Paso 2b · El script completo

:::pista Cómo hacerlo
`scripts/siguiente-version`:
```bash
#!/usr/bin/env bash
set -euo pipefail
ultima=$(git tag --list 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)
if [ -n "$ultima" ]; then rango="$ultima..HEAD"; v=${ultima#v}; else rango=HEAD; v=0.0.0; fi
IFS=. read -r ma mi pa <<< "$v"
re_rompe='^[a-z]+(\([^)]*\))?!:'
re_feat='^feat(\([^)]*\))?:'
re_fix='^(fix|perf)(\([^)]*\))?:'
nivel=0      # 0 nada · 1 patch · 2 minor · 3 major
while IFS= read -r -d '' msg; do
  asunto=${msg%%$'\n'*}
  if [[ $asunto =~ $re_rompe ]] || grep -qE '^BREAKING[ -]CHANGE:' <<< "$msg"; then nivel=3
  elif [[ $asunto =~ $re_feat ]]; then [ "$nivel" -lt 2 ] && nivel=2
  elif [[ $asunto =~ $re_fix ]]; then [ "$nivel" -lt 1 ] && nivel=1
  fi
done < <(git log -z --format=%B "$rango")
case $nivel in
  0) exit 1 ;;
  1) pa=$((pa + 1)) ;;
  2) mi=$((mi + 1)); pa=0 ;;
  3) if [ "$ma" -eq 0 ]; then mi=$((mi + 1)); pa=0; else ma=$((ma + 1)); mi=0; pa=0; fi ;;
esac
echo "$ma.$mi.$pa"
```

| Pieza | Qué hace |
|---|---|
| `${ultima#v}` | Quita la `v` del principio (`v1.4.2` → `1.4.2`). |
| `IFS=. read -r ma mi pa` | Parte la versión por los puntos en tres variables. |
| `git log -z --format=%B` | El mensaje completo (`%B`: asunto y cuerpo) de cada commit, separados por un carácter nulo (`-z`), porque un mensaje puede tener varias líneas. |
| `read -r -d ''` | Lee hasta el carácter nulo: un mensaje entero en cada vuelta. |
| `${msg%%$'\n'*}` | Se queda con la primera línea (el asunto). |
| `[[ $asunto =~ $re ]]` | Compara con una expresión regular. `(\([^)]*\))?` admite un ámbito opcional entre paréntesis, como `fix(pedidos):`. |
| `nivel` | Guarda el cambio más alto visto: un `fix` no rebaja un `feat` anterior. |

Pruébalo:
```bash
chmod +x scripts/siguiente-version
scripts/siguiente-version
```
**Qué deberías ver:** `2.0.0`.
:::

## Paso 3 · Publicar

:::pista Cómo hacerlo
```bash
NV=$(scripts/siguiente-version)
echo "$NV" > VERSION        # y la sección nueva arriba del CHANGELOG
git add -A && git commit -m "chore(release): $NV"
git tag -a "v$NV" -m "Release v$NV"
git cat-file -t "v$NV"
bash /opt/lab/check.sh
```
`git tag -a` crea una etiqueta **anotada**: un objeto propio con autor, fecha
y mensaje. `git cat-file -t` debe decir `tag` (una etiqueta ligera diría
`commit`). La sección del `CHANGELOG.md` va arriba, con `### Cambios
incompatibles` (explicando qué tiene que cambiar quien actualice),
`### Nuevas funciones` y `### Correcciones`.
:::

## Cómo actuar en una situación así

- Revisa el tipo de commit en la PR (un linter de commits en CI) y no tendrás que adivinar.
- Explica el cambio incompatible en el CHANGELOG: qué hacer para migrar.
- Herramientas que lo automatizan: semantic-release, release-please, git-cliff.
