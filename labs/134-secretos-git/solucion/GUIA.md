# Resolución guiada · Lab 134

:::piensa Antes de tocar nada
Borrar un secreto en un commit nuevo no lo borra: sigue en el historial y en
cada clon. Un secreto que estuvo en git se da por filtrado. Lo único que lo
neutraliza es rotarlo.
:::

## Paso 1 · ¿Qué hay en el historial?

:::pista Cómo comprobarlo
```bash
cd /srv/repos/pagos
git log --oneline --all
gitleaks detect --source . --report-format json --report-path ~/gitleaks.json --exit-code 0
jq -r '.[] | "\(.RuleID) \(.Commit[0:7]) \(.File)"' ~/gitleaks.json | sort -u
```
:::

## Paso 2 · Segunda opinión

**Pregúntate:** dos herramientas con reglas distintas, ¿encuentran lo mismo?

:::pista Cómo comprobarlo
```bash
trufflehog git file:///srv/repos/pagos --no-verification --no-update
```
:::

## Paso 3 · Inventario

En `~/secretos.txt`: una línea por secreto con tipo (AWS, GitHub, Stripe) y el hash corto del commit donde entró.

## Paso 4 · Rota

**Pregúntate:** ¿qué pasa si limpias el historial pero no rotas? Quien lo copió ya lo tiene.

:::pista Cómo hacerlo
```bash
for v in $(jq -r '.[].Secret' ~/gitleaks.json | sort -u); do rotar-secreto "$v"; done
```
:::

## Paso 5 · HEAD limpio y bloqueo de nuevos

:::pista Cómo hacerlo
```bash
nano deploy.sh      # GITHUB_TOKEN desde el entorno, no escrito
git commit -am "deploy.sh: el token sale del entorno"
cat > .git/hooks/pre-commit <<'HK'
#!/bin/sh
exec gitleaks protect --staged --redact -v
HK
chmod +x .git/hooks/pre-commit
```
Pruébalo: añade un token falso y verás el commit rechazado.
:::

## Cómo actuar en una situación así

- **Rotar primero, limpiar historial después** (`git filter-repo`), y avisar a todos los que tengan clones.
- **Pre-commit local + escaneo en CI** (el hook se puede saltar con `--no-verify`).
- Activa la protección de push de tu plataforma (GitHub push protection).

## Si te atascas

- `gitleaks` no encuentra nada: estás fuera del repo o falta `--source .`.
- El hook no se ejecuta: falta `chmod +x` o la línea `#!/bin/sh`.
