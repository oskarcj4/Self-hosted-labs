# Solución — Día 08: Usuario dedicado para un servicio

## 1. Estado inicial

```bash
ps -o user,pid,cmd -C reportd          # root
systemctl cat reportd                  # sin User= -> root
ls -ld /var/lib/reportd/reports /var/log/reportd ; ls -l /etc/reportd/reportd.conf
```

## 2. Crear la identidad

```bash
sudo useradd --system --no-create-home --home-dir /var/lib/reportd \
             --shell /usr/sbin/nologin reportd
id reportd     # uid < 1000, sólo su grupo
```

## 3. Darle sólo lo que necesita

```bash
sudo chown -R reportd:reportd /var/lib/reportd /var/log/reportd   # escribe aquí
sudo chown root:reportd /etc/reportd/reportd.conf                 # lee esto
sudo chmod 0640 /etc/reportd/reportd.conf                         # (no público)
```

## 4. Cambiar la unidad (con un drop-in)

```bash
sudo mkdir -p /etc/systemd/system/reportd.service.d
sudo tee /etc/systemd/system/reportd.service.d/user.conf >/dev/null <<'EOF'
[Service]
User=reportd
Group=reportd
EOF
sudo systemctl daemon-reload
sudo systemctl restart reportd
```

(`sudo systemctl edit reportd` hace lo mismo de forma interactiva.)

## 5. Verificar

```bash
ps -o user,pid,cmd -C reportd                   # reportd
curl -s http://127.0.0.1:8400/health            # reportd ok user=reportd ...
ls -l /var/lib/reportd/reports | tail -2        # ficheros nuevos de reportd
```

Si falla: `journalctl -u reportd -n 20` mostrará `PermissionError` con la ruta exacta.

## Lecciones

- Un servicio por identidad: si cae `reportd`, el atacante es `reportd`, no root.
- Usuario de sistema: `--system`, sin shell (`nologin`), sin contraseña, sin grupos extra.
- Mueve **la propiedad de lo que el servicio escribe**, y da **lectura** (no
  propiedad) de su configuración.
- Prefiere drop-ins (`.service.d/*.conf`) a editar la unidad original: sobreviven a actualizaciones.
- Siguiente nivel: `DynamicUser=yes`, `ProtectSystem=strict`, `ReadWritePaths=`.
