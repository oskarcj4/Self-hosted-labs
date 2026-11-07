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

## Paso 3 · Publicar

:::pista Cómo hacerlo
```bash
NV=$(scripts/siguiente-version)
echo "$NV" > VERSION        # y la sección nueva arriba del CHANGELOG
git add -A && git commit -m "chore(release): $NV"
git tag -a "v$NV" -m "Release v$NV"
```
:::

## Cómo actuar en una situación así

- Revisa el tipo de commit en la PR (un linter de commits en CI) y no tendrás que adivinar.
- Explica el cambio incompatible en el CHANGELOG: qué hacer para migrar.
- Herramientas que lo automatizan: semantic-release, release-please, git-cliff.
