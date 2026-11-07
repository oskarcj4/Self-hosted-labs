# Solución — Escaneo en el pipeline

## Pipeline

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m pytest -q tests
trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 .
semgrep scan --config ci/semgrep --error --metrics=off --disable-version-check --quiet .
echo "PIPELINE OK"
```

## Código

```python
cur.execute("SELECT id, total FROM pedidos WHERE cliente = ?", (cliente,))

ruta = os.path.join("/srv/facturas", os.path.basename(nombre))
return subprocess.call(["gzip", "-k", "--", ruta])
```

`config.py`:
```python
import os
PASSWORD_MIN_LEN = 12  # nosemgrep: secreto-en-codigo - es la longitud mínima de una clave, no una clave
ADMIN_PASSWORD = os.environ["ADMIN_PASSWORD"]
```

## Dependencias

| Paquete | Antes | Después |
|---------|-------|---------|
| flask | 0.12.2 | 3.1.1 |
| pyyaml | 5.3 (CRITICAL: ejecución de código en `full_load`) | 6.0.2 |
| requests | 2.19.1 | 2.32.4 |
| jinja2 | 2.10 | 3.1.6 |

Las versiones exactas dependen de la base de datos de Trivy del día de la
construcción: lo que vale es que `trivy fs` no muestre HIGH/CRITICAL.

## Por qué

- SCA (Trivy) y SAST (Semgrep) cubren cosas distintas: el código de otros y el tuyo.
- La contraseña ya está en el historial de git: además de quitarla, hay que
  rotarla (el lab 175 lo trabaja con Vault).

## Más allá del lab

- Sube los resultados en SARIF para verlos en el PR.
- Escanea también la imagen final (`trivy image`), no sólo las dependencias (lab 142).
- Renovate para que las subidas de versión lleguen solas (lab 210).
