# Resolución guiada · Lab 96

:::piensa Un tag es un puntero que otro puede mover
`uses: actions/checkout@v4` no dice qué código se ejecuta: dice "lo que
apunte hoy el tag `v4`". Quien controle ese repositorio puede mover el tag a
otro commit y ese código se ejecuta en tu runner, con tus secretos (pasó con
`tj-actions/changed-files` en 2025). Un **SHA de commit** es inmutable: fija
exactamente qué se ejecuta. Hay tres trabajos: arreglar el escáner, resolver
cada tag a su commit y no fijar uno comprometido.
:::

**El plan:** (1) ver qué se le escapa al escáner, (2) reescribirlo,
(3) resolver cada ref al commit, (4) evitar la versión comprometida y
(5) escribir el workflow.

## Paso 1 · ¿Qué no ve el escáner?

:::pista Cómo hacerlo
```bash
cd ~/gha-pin
cat pin-scan.sh .github/workflows/ci.yml SECURITY-ADVISORY.md
./pin-scan.sh
```
**Qué deberías ver:** el escáner sólo mira líneas que empiezan por `- uses:`.
Se le escapan el `uses:` que va debajo de un `- name:`, el de un job que llama
a un *reusable workflow*, los valores entre comillas… Y acepta cualquier cosa
que **empiece** por 40 hexadecimales, aunque lleve algo detrás.
:::

## Paso 2 · Un escáner que mire todos los `uses:`

:::pista Cómo hacerlo
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
f="${1:-.github/workflows/ci.yml}"
n=0
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*(.*)$ ]] || continue
  v="${BASH_REMATCH[2]%%#*}"
  v=$(tr -d "[:space:]\"'" <<<"$v")
  case "$v" in
    ./*) continue ;;
    docker://*) [[ "$v" =~ @sha256:[0-9a-f]{64}$ ]] && continue ;;
    *) [[ "$v" =~ @[0-9a-f]{40}$ ]] && continue ;;
  esac
  echo "UNPINNED: $line"; n=$((n+1))
done < "$f"
[ "$n" -eq 0 ] || { echo "pin-scan: $n uses sin pin"; exit 1; }
echo "pin-scan: todas las actions fijadas"
```

| Pieza | Qué hace |
|---|---|
| `[[ $line =~ regex ]]` | Compara con una expresión regular; las partes entre paréntesis quedan en `BASH_REMATCH`. |
| `^[[:space:]]*(-[[:space:]]+)?uses:` | `uses:` al principio de la línea (tras espacios), con o sin el guion de lista delante. |
| `${…%%#*}` | Borra desde el primer `#` hasta el final: el comentario. Así un SHA escrito sólo en el comentario no cuenta. |
| `tr -d "[:space:]\"'"` | Quita espacios y comillas. |
| `./*` | Acción local: viaja en tu propio commit, no hace falta fijarla. |
| `@sha256:[0-9a-f]{64}$` | Imagen Docker por digest completo. |
| `@[0-9a-f]{40}$` | SHA de commit completo, y nada detrás (`$`). Un SHA corto no vale: podría coincidir con otro commit. |
:::

## Paso 3 · Resuelve cada ref al commit

**Pregúntate:** para un tag anotado, `git ls-remote` da dos líneas. ¿Cuál
necesitas?

:::pista Cómo hacerlo
```bash
git ls-remote --tags /srv/gh/actions/checkout.git | grep v4
git -C /srv/gh/actions/checkout.git rev-parse 'v4^{commit}'
```
Un tag **anotado** es un objeto propio (con autor, fecha y mensaje) que apunta
a un commit. `ls-remote` enseña el hash del objeto tag y, en la línea que
acaba en `^{}`, el del commit. `uses:` necesita el **commit**:
`rev-parse 'v4^{commit}'` "pela" el tag hasta llegar a él.
:::

## Paso 4 · La versión comprometida

:::pista Cómo hacerlo
```bash
git -C /srv/gh/acme/tool.git log --oneline --decorate --all
git -C /srv/gh/acme/tool.git show v1:action.yml
git -C /srv/gh/acme/tool.git show v1.3.0:action.yml
```
`git show <ref>:<fichero>` enseña ese fichero tal como está en esa versión.

**Qué deberías ver:** en `v1`, un `curl` hacia un dominio de exfiltración. El
tag `v1` se movió a la versión comprometida, como dice el advisory. Fija la
última buena: `v1.3.0^{commit}`.
:::

## Paso 5 · El workflow fijado

:::pista Cómo hacerlo
Para cada `uses:` remoto, el SHA del commit y la versión en un comentario:
```yaml
      - uses: actions/checkout@<sha de v4> # v4.2.2
```
Puedes generarlo con la shell, sustituyendo los `$(…)` al escribir:
```bash
c(){ git -C "/srv/gh/$1.git" rev-parse "$2^{commit}"; }
c actions/checkout v4
```
Mantén todos los steps y jobs (también la acción local y el reusable
workflow de `release`). Después:
```bash
./pin-scan.sh
bash /opt/lab/check.sh
```
El comentario `# v4.2.2` no es decorativo: Dependabot y Renovate lo leen para
proponer actualizaciones del pin.
:::

## Cómo actuar en una situación así

- Fija todas las acciones de terceros a un SHA completo, y deja que una
  herramienta te proponga las actualizaciones.
- Revisa el código de la acción antes de cambiar el pin, no después.
- Limita los permisos del token del workflow (`permissions:`) para reducir lo
  que puede hacer una acción comprometida.

## Si te atascas

- **El check dice que un pin apunta al objeto tag:** usaste la línea de
  `ls-remote` sin `^{}`. Usa `rev-parse 'ref^{commit}'`.
- **El escáner no detecta un caso:** pruébalo línea a línea con
  `[[ "$line" =~ … ]] && echo "${BASH_REMATCH[2]}"`.
- **`acme/tool` falla:** apunta a `v1.3.0`, no a `v1` ni a `v1.3.1`.
