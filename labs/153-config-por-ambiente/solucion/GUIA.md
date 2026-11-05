# Resolución guiada · Lab 153

:::piensa Config fuera del código
La misma imagen debe correr en dev y prod. Si un valor está en el código, ya
no es la misma imagen: hay que recompilar. Saca TODO al entorno.
:::

## Paso 1 · La app lee del entorno

:::pista Cómo hacerlo
Sustituye los valores quemados por `os.environ.get`:
```python
import os
SECRET_KEY = os.environ.get("SECRET_KEY", "")
```
Repite con `APP_ENV`, `LOG_LEVEL`, `DB_HOST`. Ningún secreto literal.
:::

## Paso 2 · EnvironmentFile 600

:::pista Cómo hacerlo
```bash
sudo install -d -m 0755 /etc/allsafe
sudo tee /etc/allsafe/app.env >/dev/null <<'EOF'
APP_ENV=prod
LOG_LEVEL=INFO
DB_HOST=db-prod.allsafe.local
SECRET_KEY=s3cr3t-allsafe-prod-KEY
EOF
sudo chmod 600 /etc/allsafe/app.env
```
:::

## Paso 3 · El servicio lo carga y reinicia

:::pista Cómo hacerlo
Añade `EnvironmentFile=/etc/allsafe/app.env` bajo `[Service]`, luego:
```bash
sudo systemctl daemon-reload
sudo systemctl restart allsafe-api
curl -s localhost:8080/
```
:::

## Cómo actuar en una situación así

- Un valor que cambia entre ambientes = variable de entorno, nunca constante.
- Secretos: fichero con permisos mínimos hoy, gestor de secretos mañana.

## Si te atascas

- `env` sigue diciendo el valor viejo: ¿reiniciaste el servicio tras editar?
- `secret_set:false`: el servicio no ve `SECRET_KEY`; revisa el `EnvironmentFile`
  y que el unit lo cargue (`sudo systemctl cat allsafe-api`).
