# Resolución guiada · Lab 174

:::piensa Un escaneo que no bloquea es un informe que nadie lee
`|| true` convierte cualquier hallazgo en "verde". Primero haz que el gate
muerda (exit code ≠ 0), y luego arregla lo que muerde.
:::

## Paso 1 · El gate

:::pista Cómo hacerlo
```bash
trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 .
semgrep scan --config ci/semgrep --error --metrics=off .
```
Quita los `|| true` y usa `set -euo pipefail`. `ci-run` se pondrá rojo: bien.
:::

## Paso 2 · Lo que encuentra Semgrep

:::pista Qué cambiar
- `cur.execute(f"... '{cliente}'")` → `cur.execute("... = ?", (cliente,))`.
- `subprocess.call(f"gzip ...", shell=True)` → lista de argumentos, sin shell,
  y `os.path.basename(nombre)` para no salir del directorio.
- `ADMIN_PASSWORD = "..."` → `os.environ["ADMIN_PASSWORD"]`.
:::

:::pista El falso positivo
```python
PASSWORD_MIN_LEN = 12  # nosemgrep: secreto-en-codigo - longitud mínima, no es una clave
```
Suprime **esa** regla en **esa** línea, con motivo. Nunca desactives la regla entera.
:::

## Paso 3 · Lo que encuentra Trivy

:::pista Qué mirar
La columna "Fixed Version" de cada CVE. Sube cada paquete a una versión igual
o superior a todas sus "Fixed Version" HIGH/CRITICAL.
:::

## Cómo actuar en una situación así

- Introduce el gate en modo informe una semana, arregla lo existente, y luego hazlo bloqueante.
- Cada supresión lleva motivo y, si es un riesgo aceptado, fecha de revisión.
- Reglas versionadas en el repo (como `ci/semgrep`): el pipeline no depende de internet.

## Si te atascas

- Semgrep no encuentra nada: ¿pasaste `--config ci/semgrep` y la ruta `.`?
- Trivy sigue rojo tras subir versiones: mira si es otra dependencia o la misma con otra CVE.
