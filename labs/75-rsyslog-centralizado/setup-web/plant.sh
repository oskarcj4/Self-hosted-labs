#!/usr/bin/env bash
# web-02 (lab 75): genera logs de la app por syslog (tag pagos-web, numerados)
# y los manda a log-01 por UDP, sin cola: si el colector cae, se pierden.
set -e
id admin >/dev/null 2>&1 || useradd -m -s /bin/bash admin
echo 'admin:Web02-2026' | chpasswd
echo 'admin ALL=(ALL) ALL' > /etc/sudoers.d/admin && chmod 0440 /etc/sudoers.d/admin
systemctl enable --now ssh

cat > /usr/local/bin/pagos-web <<'EOF'
#!/bin/bash
# Simula la app de pagos: una línea de log por pedido, numerada.
n=0
while :; do
  n=$((n + 1))
  logger -t pagos-web -p local0.info "pedido=$n importe=$(( (n * 37) % 500 )).99 estado=cobrado"
  sleep 1
done
EOF
chmod 0755 /usr/local/bin/pagos-web
cat > /etc/systemd/system/pagos-web.service <<'EOF'
[Unit]
Description=pagos-web (app de pagos)

[Service]
ExecStart=/usr/local/bin/pagos-web
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/rsyslog.d/90-remoto.conf <<'EOF'
# Envío al colector central (2022). Ojo: "@" = UDP.
*.* @log-01:514
EOF
systemctl daemon-reload
systemctl enable --now rsyslog pagos-web
systemctl restart rsyslog
echo "web-02 plantado."
