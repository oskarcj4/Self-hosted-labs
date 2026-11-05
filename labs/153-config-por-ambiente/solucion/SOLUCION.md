# Solución — Configuración por ambiente

## Qué pasaba

`app.py` traía `APP_ENV`, `LOG_LEVEL`, `DB_HOST` y `SECRET_KEY` escritos en el
código. Imposible reutilizar la imagen entre ambientes y el secreto expuesto.

## Arreglo

1. **App lee del entorno** (`os.environ.get`), con defaults seguros y sin secreto:

```python
import os
APP_ENV    = os.environ.get("APP_ENV", "dev")
LOG_LEVEL  = os.environ.get("LOG_LEVEL", "INFO")
DB_HOST    = os.environ.get("DB_HOST", "localhost")
SECRET_KEY = os.environ.get("SECRET_KEY", "")
```

2. **EnvironmentFile** con permisos `600`:

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

3. **El unit lo carga**:

```ini
[Service]
EnvironmentFile=/etc/allsafe/app.env
ExecStart=/usr/bin/python3 /opt/allsafe/app.py
```

4. `sudo systemctl daemon-reload && sudo systemctl restart allsafe-api`

## Más allá del lab

- El secreto en un fichero `600` es el mínimo. En producción va a un gestor de
  secretos (Vault, ver lab 173) y se inyecta en tiempo de arranque.
- `EnvironmentFile` por ambiente: `app.dev.env`, `app.prod.env`. El pipeline
  elige cuál monta; la imagen no cambia.
- Nunca loguees `SECRET_KEY`. `secret_set:true/false` basta para diagnóstico.
