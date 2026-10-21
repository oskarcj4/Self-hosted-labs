#!/usr/bin/env bash
# Lab 66: 'ingest' se cae con "Too many open files" desde que la carga creció.
# El límite está en la unit (LimitNOFILE=64). Un compañero ya lo "subió" en
# limits.conf, que no aplica a los servicios de systemd.
set -e
id ingest >/dev/null 2>&1 || useradd -r -m -s /bin/bash ingest
install -m 0755 /opt/lab/setup/ingest.py /usr/local/lib/ingest.py
mkdir -p /srv/ingest/inbox
for i in $(seq -w 1 500); do
  printf '{"lote":%d,"origen":"tpv-%02d","lineas":%d}\n' "$((10#$i))" "$((10#$i % 37))" "$((10#$i * 7 % 300))" \
    > /srv/ingest/inbox/lote-$i.json
done
chown -R ingest:ingest /srv/ingest

cat > /etc/systemd/system/ingest.service <<'EOF'
[Unit]
Description=ingest (carga de lotes de TPV)
After=network.target

[Service]
User=ingest
ExecStart=/usr/bin/python3 /usr/local/lib/ingest.py
Restart=on-failure
RestartSec=5
# Plantilla corporativa de 2019 ("servicio pequeño").
LimitNOFILE=64

[Install]
WantedBy=multi-user.target
EOF

cat >> /etc/security/limits.conf <<'EOF'

# INC-6588: ingest se queda sin descriptores. Subido a 65535. (jlopez)
ingest  soft  nofile  65535
ingest  hard  nofile  65535
EOF

systemctl daemon-reload
systemctl enable ingest >/dev/null 2>&1
systemctl start ingest || true

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-6606.txt <<'EOF'
INC-6606 · ingest-01 · ingest caído
- Desde el lunes entran ~500 lotes por ventana (antes ~40). ingest arranca y
  muere en bucle.
- jlopez (INC-6588) subió el límite en /etc/security/limits.conf. Comprobado:
  "sudo -u ingest bash -c 'ulimit -n'" ya da 65535... y sigue cayéndose.
- Política: 4096 descriptores para servicios de este tipo. No editar la unit
  del paquete; los cambios, en un drop-in.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 66 plantado."
