# Solución — Pruebas de infraestructura

1. Bug: `locals.puertos = [for i in range(var.replicas) : var.puerto + i]`.
2. `modules/servicio/tests/contrato.tftest.hcl` con 9 `run`:

| run | Qué protege | Mutante que detecta |
|-----|-------------|---------------------|
| `una_replica_por_puerto` | upstream en puerto+i, uno por réplica, `server_name` | mismo puerto, server_name |
| `fichero_env` | `.env` exacto | falta ENTORNO |
| `rechaza_puerto_privilegiado` / `rechaza_puerto_fuera_de_rango` | validación de puerto | puerto sin validar |
| `acepta_limites_de_puerto` | no rechazar 1024 | validación demasiado estricta |
| `prod_exige_dos_replicas` / `dev_admite_una_replica` | regla de prod | prod con 1 réplica |
| `rechaza_mayusculas` / `rechaza_nombre_que_empieza_por_numero` | formato del nombre | nombre con mayúsculas |

3. `ci/test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform fmt -check -recursive
terraform -chdir=modules/servicio init -input=false -backend=false
terraform -chdir=modules/servicio validate
terraform -chdir=modules/servicio test
```

El fichero de pruebas completo está en `solve.sh`.

## Pruebas de mutación

Una batería que pasa siempre no demuestra nada. El check copia el módulo,
introduce un fallo (un mutante) y ejecuta tus pruebas: si siguen en verde,
el mutante "sobrevive" y hay una promesa del módulo que nadie vigila. Es la
misma idea que en el lab 186, aplicada a infraestructura.
