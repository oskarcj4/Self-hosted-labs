# Resolución guiada · Lab 96

:::piensa
Tres trabajos distintos: arreglar el escáner (no ve todos los `uses:`),
resolver cada tag al commit correcto, y no fijar un commit comprometido.
:::

## Paso 1 · ¿Qué no ve el escáner?

Sólo mira líneas `- uses:`. Se le escapan `uses:` debajo de `- name:` y el
`uses:` de un job que llama a un reusable workflow. Además acepta cualquier
cosa que *empiece* por 40 hex y marca como malas las acciones locales.

Reescríbelo con `[[ $line =~ ^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*(.*)$ ]]`,
quita el comentario (`${v%%#*}`) y las comillas, y exige:

- `./…` → OK.
- `docker://…` → `@sha256:[0-9a-f]{64}$`.
- resto → `@[0-9a-f]{40}$` (con `$`: nada detrás).

## Paso 2 · Resuelve cada ref al commit

```bash
git -C /srv/gh/actions/checkout.git rev-parse 'v4^{commit}'
```

`git ls-remote --tags` da dos líneas para un tag anotado: el objeto tag y la
`^{}`, que es el commit. `uses:` necesita el **commit**.

## Paso 3 · acme/tool

`git -C /srv/gh/acme/tool.git show v1:action.yml` → `curl` a un dominio de
exfiltración. Fija `v1.3.0^{commit}`, no `v1`.

## Paso 4 · Comentario de versión

`- uses: actions/checkout@<sha40> # v4.2.2`. Dependabot y Renovate leen ese
comentario para proponer updates del pin.
