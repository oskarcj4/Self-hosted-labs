# Solución — Actions sin pin de SHA

## 1. El escáner tenía tres agujeros

| Caso | Escáner viejo | Por qué |
|------|---------------|---------|
| `- name: lint` + `uses: acme/lint@v2` | no lo ve | sólo mira líneas `- uses:` |
| job `release: uses: …/release.yml@main` | no lo ve | ídem: reusable workflow a nivel de job |
| `@<sha40>-evil` | lo acepta | regex sin `$` |
| `./.github/actions/x` | lo marca | las locales no llevan `@` y no lo necesitan |

```bash
[[ "$line" =~ ^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*(.*)$ ]] || continue
v="${BASH_REMATCH[2]%%#*}"; v=$(tr -d "[:space:]\"'" <<<"$v")
case "$v" in
  ./*) continue ;;
  docker://*) [[ "$v" =~ @sha256:[0-9a-f]{64}$ ]] && continue ;;
  *) [[ "$v" =~ @[0-9a-f]{40}$ ]] && continue ;;
esac
echo "UNPINNED: $line"
```

## 2. Tag → commit

```bash
git -C /srv/gh/actions/checkout.git rev-parse 'v4^{commit}'
```

Un tag anotado es un objeto propio con su SHA. `ls-remote` lo enseña y luego
la línea `refs/tags/v4.2.2^{}` con el commit. GitHub Actions necesita el SHA
del **commit**.

Ojo con `actions/checkout`: `main` ya tiene un commit `wip` por delante de
`v4`. Fijar "lo último" no es fijar lo publicado.

## 3. Pin a un commit malo = malware inmutable

`v1` y `v1.3.1` de `acme/tool` apuntan al commit `chore: telemetry` que hace
`curl …?t=$GITHUB_TOKEN`. Fijarlo por SHA te protege de *futuros* cambios del
tag, pero congela el compromiso. Antes de fijar, decide **qué** fijas:

```yaml
- uses: acme/tool@<v1.3.0^{commit}> # v1.3.0 (v1/v1.3.1 comprometidos, GHSA-tc96)
```

## Lecciones

- El tag es un puntero mutable. El SHA del commit es el contenido.
- Fija el commit, no el objeto tag anotado.
- Las reusable workflows (`jobs.<id>.uses`) también son código de terceros.
- Comentario `# vX.Y.Z` tras el SHA: legible y actualizable por Dependabot o Renovate.
- Pin sin revisión no basta: tras un advisory, comprueba qué versión es buena
  y rota los secretos de las ejecuciones afectadas.
- En la org: política "Require actions to be pinned to a full-length commit
  SHA" y `permissions:` mínimos para que un `GITHUB_TOKEN` robado valga poco.
