#!/usr/bin/env bash
# Lab 55: disco de logs al 100 % (un rotado enorme + un fichero borrado que un
# demonio sigue teniendo abierto) y el disco de sesiones sin inodos.
# Los dos "discos" son tmpfs con tamaño e inodos limitados, para que df/df -i
# den números reales sin llenar el disco de tu máquina.
set -e
id orders >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin orders
install -m 0755 /opt/lab/setup/orders.py /usr/local/lib/orders.py
install -m 0755 /opt/lab/setup/trace_collector.py /usr/local/lib/trace_collector.py

mkdir -p /var/log/app /srv/sessions
mountpoint -q /var/log/app || mount -t tmpfs -o size=100m,mode=0755 tmpfs /var/log/app
mountpoint -q /srv/sessions || mount -t tmpfs -o size=16m,nr_inodes=1000,mode=0755 tmpfs /srv/sessions
chown orders:orders /var/log/app /srv/sessions
mkdir -p /var/lib/trace-collector && chown orders:orders /var/lib/trace-collector

unit() {  # unit NOMBRE SCRIPT "Descripción"
  cat > "/etc/systemd/system/$1.service" <<EOF
[Unit]
Description=$3
After=network.target

[Service]
User=orders
ExecStart=/usr/bin/python3 /usr/local/lib/$2
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
}
unit orders orders.py "Orders (procesado de pedidos)"
unit trace-collector trace_collector.py "Colector de trazas de depuración"
systemctl daemon-reload

# --- Sesiones: 15 vivas y el resto antiguas hasta agotar los inodos
for i in $(seq -w 1 15); do echo "user=$i" > /srv/sessions/sess-live-$i; done
i=0
while :; do
  i=$((i+1))
  touch -d '3 days ago' "/srv/sessions/sess-old-$i" 2>/dev/null || break
done
chown -R orders:orders /srv/sessions

# --- Logs: el colector vuelca 40 MB en un fichero que mantiene abierto...
echo "$(date +%FT%T) INFO orders arrancando" > /var/log/app/orders.log
chown orders:orders /var/log/app/orders.log
systemctl enable --now trace-collector
for _ in $(seq 1 60); do [ -e /var/lib/trace-collector/.filled ] && break; sleep 1; done
# ...un rotado sin comprimir se come el resto...
yes "2026-10-18T03:00:01 INFO order processed id=0000 total=19.99 user=anon path=/checkout/confirm" \
  > /var/log/app/orders.log.1 2>/dev/null || true
chown orders:orders /var/log/app/orders.log.1
# ...y alguien "liberó espacio" borrando el log del colector sin pararlo.
rm -f /var/log/app/debug-trace.log

systemctl enable --now orders

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-3107.txt <<'TXT'
INC-3107 · Prioridad 1 · stor-01
- Alertas: "orders /health devuelve 500".
- El de guardia dice: "borré el log de depuración enorme de trace-collector
  y df sigue diciendo 100 %. No entiendo nada."
- Soporte: los usuarios no pueden iniciar sesión ("No space left on device"),
  pero en /srv/sessions casi no hay datos.
- Este servidor no tiene logrotate configurado para /var/log/app.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 55 plantado."
