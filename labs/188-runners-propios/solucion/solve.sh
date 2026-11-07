#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e

# 1. Usuario de sistema, dueño sólo de su directorio de trabajo.
id ci-runner >/dev/null 2>&1 || sudo useradd --system --no-create-home --home-dir /srv/ci --shell /usr/sbin/nologin ci-runner
sudo mkdir -p /srv/ci
sudo chown -R ci-runner:ci-runner /srv/ci
sudo chmod 750 /srv/ci

# 2-5. Configuración del runner.
sudo tee /etc/runner/runner.ini > /dev/null <<'INI'
[runner]
base = /srv/ci
espacio_efimero = si
timeout = 60
etiquetas = linux, x64
heredar_entorno = no
INI

# 3. El token, fuera de la unidad: fichero 0600 que systemd lee como root.
TOKEN=$(systemctl show runner -p Environment --value | tr ' ' '\n' | sed -n 's/^REGISTRY_TOKEN=//p')
echo "REGISTRY_TOKEN=$TOKEN" | sudo tee /etc/runner/token.env > /dev/null
sudo chmod 600 /etc/runner/token.env

# 6. Unidad con sandbox.
sudo tee /etc/systemd/system/runner.service > /dev/null <<'U'
[Unit]
Description=Runner de CI propio
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/runner/runner.py
EnvironmentFile=/etc/runner/token.env
User=ci-runner
Group=ci-runner
Restart=always

# Sandbox: un job malicioso no puede escalar, ni tocar el sistema, ni ver /home.
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/srv/ci
ProtectHome=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
# Recursos: ni minar ni tumbar el servidor.
MemoryMax=1G
TasksMax=256
CPUQuota=200%

[Install]
WantedBy=multi-user.target
U
sudo systemctl daemon-reload
sudo systemctl restart runner
sleep 1
systemctl status runner --no-pager | head -5
ci-job 'id; pwd; env | sort'
echo "solve.sh completado."
