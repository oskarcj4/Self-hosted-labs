#!/usr/bin/env bash
# Lab 65: el deploy de la r43 de 'shop' ha tirado el servicio. Hay que volver
# a la r42. El 'rollback' del script de despliegue elige la release equivocada.
set -e
id shop >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin shop
B=/srv/shop
mkdir -p $B/releases $B/shared/uploads
for i in $(seq 1 12); do echo "foto $i" > $B/shared/uploads/prod-$i.jpg; done
for r in 2026-09-28_1830-r41 2026-10-12_1105-r42 2026-10-20_0915-r43; do
  d=$B/releases/$r
  mkdir -p $d
  install -m 0644 /opt/lab/setup/app.py $d/app.py
  echo "${r##*-}" > $d/VERSION
  ln -s ../../shared/uploads $d/uploads
done
chown -R root:root $B && chown -R shop:shop $B/shared
ln -sfn releases/2026-10-20_0915-r43 $B/current
install -m 0755 /opt/lab/setup/deploy.sh /usr/local/bin/deploy.sh

cat > /etc/systemd/system/shop.service <<'EOF'
[Unit]
Description=shop (tienda online)
After=network.target

[Service]
User=shop
WorkingDirectory=/srv/shop/current
ExecStart=/usr/bin/python3 /srv/shop/current/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable shop >/dev/null 2>&1
systemctl start shop || true

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-6505.txt <<'EOF'
INC-6505 · shop-02 · SEV1 · la tienda no responde desde el deploy de las 09:15
- Deploy de la r43 (pipeline #2213). Justo después, shop caído.
- Decisión del responsable de guardia: ROLLBACK a la r42 (la que estaba en
  producción hasta hoy) y analizamos la r43 con calma.
- NO borres la r43: desarrollo la necesita para el análisis.
- Procedimiento: "deploy.sh rollback" (script de plataforma de 2024).
- La BD ya está en el esquema 13 (la migración se aplicó con la r42).
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 65 plantado."
