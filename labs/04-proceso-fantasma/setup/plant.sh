#!/usr/bin/env bash
# Planta el escenario del Lab 04: un proceso que se disfraza de hilo del kernel
# (kworker) corriendo desde /tmp, más un "monitor" amañado que lo oculta.
# Todo inofensivo: el proceso sólo hace un bucle ligero y duerme.
set -e

# 1) Copia python3 con el nombre "kworker" para que 'comm' muestre ese nombre.
cp "$(command -v python3)" /tmp/kworker
chmod +x /tmp/kworker

# 2) Lánzalo: bucle de CPU ligero con pausa (no satura la máquina de verdad).
nohup /tmp/kworker -c "import time
while True:
    s = 0
    for i in range(200000):
        s += i
    time.sleep(0.08)" >/dev/null 2>&1 &

# 3) Pista en un log de sistema.
mkdir -p /var/log
cat >> /var/log/syslog <<EOF
$(date '+%b %e %H:%M:%S') app-prod-04 kernel: CPU throttling: sustained load detected
$(date '+%b %e %H:%M:%S') app-prod-04 sysmon[710]: report OK cpu=0% mem=12% (nothing unusual)
EOF

echo "Lab 04 plantado. Entra como analista y lee /RETO.md"
