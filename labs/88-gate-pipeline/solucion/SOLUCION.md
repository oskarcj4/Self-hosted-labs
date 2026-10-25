# Solución — Gate de seguridad saltado

## 1. Por qué el deploy salía verde

```bash
cd ~/gate-ci
./run-ci.sh
```

`secret-scan` falla (contraseña en `app/config.py`) pero `continue-on-error: true`
lo convierte en un aviso. `deploy` no tiene `needs`, así que corre igual.

## 2. Arregla el hallazgo

```python
import os
PASSWORD = os.environ.get("APP_PASSWORD", "")
DEBUG = False
```

## 3. Haz el gate obligatorio

```yaml
jobs:
  secret-scan:
    run: bash jobs/secret-scan.sh
  deploy:
    needs: [secret-scan]
    run: bash jobs/deploy.sh
```

Sin `continue-on-error`. Si el scan vuelve a fallar, el runner aborta antes del
deploy.

## Lecciones

- `continue-on-error` en un job de seguridad es un gate de cartón.
- `needs:` convierte el scan en dependencia real, no en un job decorativo.
- Un gate rojo que no bloquea el deploy no es un control: es teatro.
