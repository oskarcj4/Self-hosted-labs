#!/usr/bin/env bash
# Lab 75 (log-01): el colector central de logs. rsyslog está instalado con la
# config por defecto: no escucha en la red.
set -e
systemctl enable --now rsyslog

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/PROB-7515.txt <<'EOF'
PROB-7515 · log-01 / web-02 · nos faltan logs
- Auditoría de pagos: en el colector (log-01) no hay NADA de web-02, y en la
  última caída del colector (el martes) se perdieron 40 minutos de logs.
- web-02 tiene un envío por UDP de 2022 (/etc/rsyslog.d/90-remoto.conf).
  Acceso: ssh admin@web-02  (contraseña: Web02-2026, tiene sudo).
- Requisitos:
  * log-01 recibe por TCP en el 514.
  * Un fichero por máquina y programa:
      /var/log/remote/<máquina>/<programa>.log
    (p. ej. /var/log/remote/web-02/pagos-web.log)
  * Los logs remotos NO se mezclan con los propios de log-01 (/var/log/syslog).
  * web-02 envía por TCP y, si log-01 cae, guarda los mensajes y los manda
    cuando vuelva (cola en disco, reintentos infinitos). Cero huecos.
- La app de web-02 (pagos-web) numera sus líneas: pedido=1, 2, 3...
  Así se ven los huecos.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 75 plantado."
