# Solución — Lab 16

## 1. Crear la unidad

```bash
sudo tee /etc/systemd/system/myapp.service >/dev/null <<'EOF'
[Unit]
Description=My App
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

## 2. Recargar y habilitar

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp.service
```

`enable` crea el enlace en `multi-user.target.wants/` (arranque al boot); `--now`
además la arranca ya.

## 3. Comprobar

```bash
systemctl status myapp.service
curl -s localhost:8000      # myapp ok
bash /opt/lab/check.sh
```

## Lecciones

- Servicializar da: arranque al boot (`enable`), reinicio automático
  (`Restart=always`), logs centralizados (`journalctl -u myapp`) y control
  uniforme (`start`/`stop`/`status`).
- `enable` ≠ `start`: uno configura el boot, el otro arranca ahora. `enable --now`
  hace ambos.
- Para apps reales: usar un usuario dedicado (`User=`), limitar permisos
  (`ProtectSystem=`, `NoNewPrivileges=`) y variables en `Environment=`.
