#!/usr/bin/env bash
# Planta el escenario del Lab 02: beacon impostor en /tmp escuchando en un
# puerto oculto, con persistencia en cron que lo revive cada minuto.
set -e

# 1) Arranca cron (la persistencia del atacante depende de él)
service cron start 2>/dev/null || cron 2>/dev/null || true

# 2) Línea de persistencia camuflada como "mantenimiento del sistema"
cat > /etc/cron.d/system-maint <<'EOF'
# Mantenimiento del sistema (NO es del sistema: lo dejó el atacante)
* * * * * root /opt/lab/.respawn.sh
EOF
chmod 644 /etc/cron.d/system-maint

# 3) Lanza el beacon por primera vez
/opt/lab/.respawn.sh

# 4) Pista de "tráfico saliente" en un log (como la alerta del video)
mkdir -p /var/log
cat >> /var/log/syslog <<EOF
$(date '+%b %e %H:%M:%S') db-prod-02 netmon[900]: ALERT outbound 2.3 GB to 45.9.148.x on tcp/4444 (process: system-update)
EOF

echo "Lab 02 plantado. Entra como analista y lee /RETO.md"
