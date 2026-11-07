# Escaneo en el pipeline

> DevSecOps · Trivy · Semgrep · SCA · SAST · gates · falsos positivos

## Escenario

`~/api/ci/pipeline.sh` ejecuta pruebas, **Trivy** (CVEs en dependencias, SCA)
y **Semgrep** (análisis estático del código, SAST). Pero cada escaneo acaba en
`|| true`, y Semgrep pide reglas de internet (`p/python`), que aquí no hay.
Resultado: el pipeline nunca ha bloqueado nada.

El repo tiene de todo: inyección SQL, `shell=True` con entrada del usuario,
una contraseña en el código y dependencias de 2018 con CVEs críticos.

Hay reglas locales en `ci/semgrep/python.yml`. Una de ellas da un **falso
positivo**: `PASSWORD_MIN_LEN = 12` no es un secreto.

`ci-run` ejecuta el pipeline sobre una copia limpia del último commit.

## Objetivos

1. Pipeline que **falla** con HIGH/CRITICAL de Trivy (`--scanners vuln`) y
   con cualquier hallazgo de Semgrep (reglas de `ci/semgrep`).
2. Arreglados: SQL con parámetros, `subprocess` sin shell, `ADMIN_PASSWORD`
   desde el entorno y dependencias sin HIGH/CRITICAL.
3. El falso positivo, **suprimido en su línea** con
   `# nosemgrep: secreto-en-codigo` y un motivo. No lo borres ni lo renombres.
4. Commit, y `ci-run` en verde.

El check mete fallos en copias del repo (SQL con f-string, `shell=True`,
PyYAML 5.3) y espera que el pipeline los pare.

## Pistas

```bash
cd ~/api && ci-run
trivy fs --scanners vuln --severity HIGH,CRITICAL .
trivy fs --scanners vuln --severity HIGH,CRITICAL --format json . | jq '.Results[].Vulnerabilities[] | {PkgName, InstalledVersion, FixedVersion}'
semgrep scan --config ci/semgrep --error --metrics=off .
echo $?        # 0 = limpio, 1 = hallazgos
```

```python
cur.execute("SELECT ... WHERE cliente = ?", (cliente,))
subprocess.call(["gzip", "-k", "--", ruta])
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
