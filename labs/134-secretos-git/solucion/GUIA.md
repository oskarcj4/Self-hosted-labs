# Resolución guiada · Lab 134

:::piensa Borrar no es olvidar
Git guarda **todas** las versiones de cada fichero. Borrar un secreto en un
commit nuevo no lo borra del historial: cualquiera que clone el repositorio
puede leerlo con `git log -p`. Un secreto que estuvo en git se da por filtrado,
y lo único que lo neutraliza es **rotarlo** (revocarlo y emitir otro).
:::

**El plan:** (1) escanear el historial, (2) contrastar con otra herramienta,
(3) hacer el inventario, (4) rotar, (5) limpiar el código actual y (6) poner un
hook que bloquee los siguientes.

## Paso 1 · ¿Qué hay en el historial?

:::pista Cómo hacerlo
```bash
cd /srv/repos/pagos
git log --oneline --all
gitleaks detect --source . --report-format json --report-path ~/gitleaks.json --exit-code 0
jq -r '.[] | "\(.RuleID) \(.Commit[0:7]) \(.File)"' ~/gitleaks.json | sort -u
```
- **gitleaks** recorre todos los commits buscando patrones de credenciales
  (formato de claves de AWS, tokens de GitHub…).
- `--exit-code 0`: termina bien aunque encuentre algo (por defecto sale con
  error, útil en CI, molesto aquí).
- El filtro `jq` recorre el informe y, de cada hallazgo, imprime la regla, los
  7 primeros caracteres del commit (`[0:7]`) y el fichero.

**Qué deberías ver:** credenciales de AWS, GitHub y Stripe, cada una con el
commit donde entró.
:::

## Paso 2 · Segunda opinión

:::pista Cómo hacerlo
```bash
trufflehog git file:///srv/repos/pagos --no-verification --no-update
```
trufflehog usa otras reglas. `--no-verification` evita que intente probar los
secretos contra los servicios reales; `--no-update` que se actualice (no hay
Internet). Dos herramientas encuentran más que una.
:::

## Paso 3 · Inventario

:::pista Cómo hacerlo
Una línea por secreto en `~/secretos.txt`, con el tipo y el commit:
```bash
jq -r '.[] | "\(.RuleID) \(.Commit[0:7]) \(.File)"' ~/gitleaks.json | sort -u > ~/secretos.txt
cat ~/secretos.txt
```
El nombre de la regla ya dice el tipo (`aws-access-token`, `github-pat`,
`stripe-access-token`). Puedes ver cómo entró cada uno con `git show <commit>`.
:::

## Paso 4 · Rota

**Pregúntate:** si limpias el historial pero no rotas, ¿qué pasa con quien ya
lo clonó?

:::pista Cómo hacerlo
Que ya tiene los secretos. Por eso se rota siempre:
```bash
for v in $(jq -r '.[] | select(.RuleID=="aws-access-token" or .RuleID=="github-pat" or .RuleID=="stripe-access-token") | .Secret' ~/gitleaks.json | sort -u); do
  rotar-secreto "$v"
done
```
`rotar-secreto` es un comando del lab que simula al proveedor. `select(…)` se
queda con los hallazgos de esas tres reglas; `.Secret` es el valor encontrado.
:::

## Paso 5 · El código actual, sin secretos

:::pista Cómo hacerlo
```bash
grep -n TOKEN deploy.sh
nano deploy.sh
```
Sustituye la línea `GITHUB_TOKEN=ghp_…` por:
```bash
: "${GITHUB_TOKEN:?define GITHUB_TOKEN en el entorno}"
```
`${VAR:?mensaje}` hace que el script pare con ese mensaje si la variable no
existe; `:` es un comando que no hace nada, sólo sirve para que se evalúe la
expresión. El token ya no está en el código: llega del entorno.
```bash
git commit -am "deploy.sh: el token sale del entorno"
```
:::

## Paso 6 · Bloquear los siguientes

:::pista Cómo hacerlo
```bash
cat > .git/hooks/pre-commit <<'HK'
#!/bin/sh
exec gitleaks protect --staged --redact -v
HK
chmod +x .git/hooks/pre-commit
```
- Git ejecuta `.git/hooks/pre-commit` antes de cada commit; si termina con
  error, el commit se cancela.
- `gitleaks protect --staged` escanea sólo lo que vas a commitear.
  `--redact` oculta el secreto en la salida.

Pruébalo con un token falso con formato de GitHub (`ghp_` + 36 caracteres;
`tr -dc` se queda sólo con letras y números de un bloque aleatorio):
```bash
echo "GITHUB_TOKEN=ghp_$(head -c 200 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 36)" > prueba.txt
git add prueba.txt && git commit -m prueba
git rm --cached -q prueba.txt; rm prueba.txt
bash /opt/lab/check.sh
```
**Qué deberías ver:** gitleaks rechazando el commit.
:::

## Cómo actuar en una situación así

- **Rotar primero.** Limpiar el historial (`git filter-repo`) es un extra y
  obliga a avisar a todos los que tengan clones.
- El hook local se salta con `--no-verify`: escanea también en la CI.
- Activa la protección de push de tu plataforma (GitHub *push protection*).

## Si te atascas

- **`gitleaks` no encuentra nada:** estás fuera del repo o falta `--source .`.
- **El hook no se ejecuta:** falta `chmod +x` o la primera línea `#!/bin/sh`.
- **`rotar-secreto` dice que no conoce el valor:** copiaste el secreto con
  espacios o comillas; usa el bucle con `jq -r`.
