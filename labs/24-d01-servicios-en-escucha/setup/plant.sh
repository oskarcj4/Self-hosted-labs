#!/usr/bin/env bash
# Lab 24 (Día 01): host con varios servicios. Unos escuchan en todas las
# interfaces y otros sólo en loopback; la documentación de traspaso está
# desactualizada a propósito.
set -e
install -m 0755 /opt/lab/setup/svc.py /usr/local/lib/svc.py
id svc >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin svc

unit() {  # unit NOMBRE HOST PUERTO "Descripción"
  cat > "/etc/systemd/system/$1.service" <<EOF
[Unit]
Description=$4
After=network.target

[Service]
User=svc
ExecStart=/usr/bin/python3 /usr/local/lib/svc.py $1 $2 $3
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}
unit inventory-api 127.0.0.1 8081 "Inventory API (consumida por nginx)"
unit metrics-exp   127.0.0.1 9100 "Exportador de métricas"
unit legacy-sync   0.0.0.0   8873 "Sincronización legacy con el ERP antiguo"
unit cache-svc     0.0.0.0   6379 "Caché de sesiones"
systemctl daemon-reload
systemctl enable --now nginx ssh inventory-api metrics-exp legacy-sync cache-svc

# Documentación de traspaso del equipo anterior (incompleta y desactualizada)
H=/home/analista
mkdir -p "$H/handoff" "$H/audit"
cat > "$H/handoff/servicios.md" <<'EOF'
# Traspaso edge-01 (equipo Plataforma, marzo)

| Servicio      | Puerto | Exposición |
|---------------|--------|------------|
| nginx         | 80     | pública    |
| sshd          | 22     | pública    |
| inventory-api | 8081   | local      |
| cache-svc     | 6379   | local      |

- legacy-sync se dio de baja en febrero.
- metrics: pendiente de documentar.
EOF
chown -R analista:analista "$H/handoff" "$H/audit"
echo "Lab 24 plantado."
